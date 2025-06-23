# DeepMimic Windows Setup Script
# PowerShell script to set up DeepMimic environment on Windows

param(
    [int]$Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = "Stop"

# Version constants
$PY_VER = "3.7.16"
$BULLET_VER = "2.88"
$EIGEN_VER = "3.3.7"
$GLEW_VER = "2.1.0"
$FREEGLUT_VER = "3.0.0"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LIBS_DIR = Join-Path $SCRIPT_DIR "libs"

Write-Host "DeepMimic Windows Setup Script" -ForegroundColor Green
Write-Host "Using $Jobs parallel jobs" -ForegroundColor Yellow

# Create libs directory
if (!(Test-Path $LIBS_DIR)) {
    New-Item -ItemType Directory -Path $LIBS_DIR | Out-Null
}
Set-Location $LIBS_DIR

# Helper function to download files
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    if (!(Test-Path $OutputPath)) {
        Write-Host "Downloading $Url..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        } catch {
            Write-Error "Failed to download $Url : $_"
            exit 1
        }
    } else {
        Write-Host "File $OutputPath already exists, skipping download" -ForegroundColor Yellow
    }
}

# Helper function to extract archives
function Extract-Archive {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath = "."
    )
    
    $extension = [System.IO.Path]::GetExtension($ArchivePath).ToLower()
    
    if ($extension -eq ".zip") {
        Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
    } elseif ($extension -eq ".gz" -or $extension -eq ".tgz") {
        # For .tar.gz files, we need 7-Zip or tar command
        if (Get-Command "tar" -ErrorAction SilentlyContinue) {
            # Use Windows 10+ built-in tar command
            & tar -xzf $ArchivePath -C $DestinationPath
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to extract $ArchivePath using tar"
                exit 1
            }
        } elseif (Get-Command "7z" -ErrorAction SilentlyContinue) {
            & 7z x $ArchivePath -o"$DestinationPath" -y
            $tarFile = $ArchivePath -replace '\.(gz|tgz)$', ''
            if (Test-Path $tarFile) {
                & 7z x $tarFile -o"$DestinationPath" -y
                Remove-Item $tarFile -Force
            }
        } else {
            Write-Warning "Neither tar nor 7-Zip found. Trying PowerShell method..."
            # Fallback: try to use .NET compression
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
            } catch {
                Write-Error "Failed to extract $ArchivePath. Please install 7-Zip or Windows Subsystem for Linux."
                exit 1
            }
        }
    }
}

# Helper function to check if build is complete
function Test-BuildComplete {
    param([string]$Directory)
    return Test-Path (Join-Path $Directory ".built")
}

# Helper function to mark build as complete
function Set-BuildComplete {
    param([string]$Directory)
    New-Item -ItemType File -Path (Join-Path $Directory ".built") -Force | Out-Null
}

# Helper function to clean up failed builds
function Reset-BuildDirectory {
    param([string]$Directory)
    $buildMarker = Join-Path $Directory ".built"
    if (Test-Path $buildMarker) {
        Remove-Item $buildMarker -Force
    }
    $buildDir = Join-Path $Directory "build"
    if (Test-Path $buildDir) {
        Write-Host "Cleaning previous build directory..." -ForegroundColor Yellow
        Remove-Item $buildDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check for required tools
$requiredTools = @("git", "cmake")
foreach ($tool in $requiredTools) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "$tool is required but not found in PATH. Please install $tool and add it to PATH."
        exit 1
    }
}

# Check for Visual Studio
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vsWhere)) {
    Write-Error "Visual Studio installer not found. Please install Visual Studio 2017 or later with C++ support."
    exit 1
}

$vsInstallPath = & $vsWhere -latest -products * -property installationPath
if (!$vsInstallPath) {
    Write-Error "Visual Studio installation not found. Please install Visual Studio 2017 or later with C++ support."
    exit 1
}

Write-Host "Found Visual Studio at: $vsInstallPath" -ForegroundColor Green

# Set up Python virtual environment
Write-Host "Setting up Python environment..." -ForegroundColor Cyan
$pythonDir = Join-Path $SCRIPT_DIR "py"
if (!(Test-Path $pythonDir)) {
    # Check if Python 3.7 is available
    $python37 = Get-Command "python3.7" -ErrorAction SilentlyContinue
    if (!$python37) {
        $python37 = Get-Command "python" -ErrorAction SilentlyContinue
        if ($python37) {
            $pythonVersion = & $python37.Source --version 2>&1
            if ($pythonVersion -notmatch "3\.7") {
                Write-Warning "Python 3.7 not found. Using available Python version: $pythonVersion"
            }
        } else {
            Write-Error "Python not found. Please install Python 3.7 and add it to PATH."
            exit 1
        }
    }
    
    & $python37.Source -m venv $pythonDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Python virtual environment"
        exit 1
    }
}

# Activate virtual environment
$activateScript = Join-Path $pythonDir "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
} else {
    Write-Error "Failed to find Python virtual environment activation script"
    exit 1
}

# Install Python packages
Write-Host "Installing Python packages..." -ForegroundColor Cyan
& python -m pip install --upgrade pip
& python -m pip install numpy PyOpenGL PyOpenGL_accelerate tensorflow==1.13.1 mpi4py "protobuf==3.20.*"

# Download Microsoft MPI installer
Write-Host "Setting up Microsoft MPI..." -ForegroundColor Cyan
$mpiInstaller = "msmpisetup.exe"
$mpiUrl = "https://github.com/microsoft/Microsoft-MPI/releases/download/v10.1.1/msmpisetup.exe"

Download-File -Url $mpiUrl -OutputPath $mpiInstaller
if (!(Get-Command "mpiexec" -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "MICROSOFT MPI INSTALLATION REQUIRED:" -ForegroundColor Red
    Write-Host "1. Run the downloaded installer: libs\$mpiInstaller" -ForegroundColor Yellow
    Write-Host "2. Follow the installation wizard to install Microsoft MPI" -ForegroundColor Yellow
    Write-Host "3. After installation, restart PowerShell and re-run this setup script" -ForegroundColor Yellow
    Write-Host ""
    Write-Error "Please install Microsoft MPI and then re-run this script."
    exit 1
}

# Download and build Bullet Physics
Write-Host "Setting up Bullet Physics $BULLET_VER..." -ForegroundColor Cyan
$bulletArchive = "bullet3-${BULLET_VER}.zip"
$bulletUrl = "https://github.com/bulletphysics/bullet3/archive/refs/tags/${BULLET_VER}.zip"
$bulletDir = "bullet3-${BULLET_VER}"

Download-File -Url $bulletUrl -OutputPath $bulletArchive
if (!(Test-Path $bulletDir)) {
    Extract-Archive -ArchivePath $bulletArchive
}

if (!(Test-BuildComplete -Directory $bulletDir)) {
    Set-Location $bulletDir
    
    # Check if install directory exists but is empty (failed previous build)
    $installLibDir = "install\lib"
    if ((Test-Path $installLibDir) -and ((Get-ChildItem $installLibDir -File).Count -eq 0)) {
        Write-Host "Previous Bullet build incomplete, cleaning up..." -ForegroundColor Yellow
        Reset-BuildDirectory -Directory "."
    }
    
    $buildDir = "build_cmake"
    if (!(Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir | Out-Null
    }
    Set-Location $buildDir
    
    & cmake -DCMAKE_INSTALL_PREFIX="..\install" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DUSE_DOUBLE_PRECISION=OFF -DBUILD_SHARED_LIBS=OFF -DINSTALL_LIBS=ON -DBUILD_BULLET2_DEMOS=OFF -DBUILD_BULLET3=ON -DBUILD_EXTRAS=OFF -DBUILD_UNIT_TESTS=OFF -A x64 ..
    if ($LASTEXITCODE -ne 0) { Write-Error "CMake configuration failed for Bullet"; exit 1 }
    
    & cmake --build . --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for Bullet"; exit 1 }
    
    & cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { Write-Error "Install failed for Bullet"; exit 1 }
    
    Set-Location ".."
    Set-BuildComplete -Directory "."
    Set-Location ".."
}

# Download Eigen (header-only library)
Write-Host "Setting up Eigen $EIGEN_VER..." -ForegroundColor Cyan
$eigenArchive = "eigen-${EIGEN_VER}.zip"
$eigenUrl = "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VER}/eigen-${EIGEN_VER}.zip"
$eigenDir = "eigen-${EIGEN_VER}"

Download-File -Url $eigenUrl -OutputPath $eigenArchive
if (!(Test-Path $eigenDir)) {
    Extract-Archive -ArchivePath $eigenArchive
}

# Eigen is header-only, no build required
if (!(Test-BuildComplete -Directory $eigenDir)) {
    Write-Host "Eigen is header-only, no build required" -ForegroundColor Green
    Set-BuildComplete -Directory $eigenDir
}

# Download GLEW (OpenGL Extension Wrangler Library)
Write-Host "Setting up GLEW $GLEW_VER..." -ForegroundColor Cyan
$glewArchive = "glew-${GLEW_VER}-win32.zip"
$glewUrl = "https://deac-ams.dl.sourceforge.net/project/glew/glew/${GLEW_VER}/glew-${GLEW_VER}-win32.zip"
$glewDir = "glew-${GLEW_VER}"

Download-File -Url $glewUrl -OutputPath $glewArchive
if (!(Test-Path $glewDir)) {
    Extract-Archive -ArchivePath $glewArchive
}

# GLEW is pre-built for Windows, no build required
if (!(Test-BuildComplete -Directory $glewDir)) {
    Write-Host "GLEW is pre-built for Windows, no build required" -ForegroundColor Green
    Set-BuildComplete -Directory $glewDir
}

# Download and build FreeGLUT
Write-Host "Setting up FreeGLUT $FREEGLUT_VER..." -ForegroundColor Cyan
$freeglutArchive = "freeglut-${FREEGLUT_VER}.tar.gz"
$freeglutUrl = "https://github.com/freeglut/freeglut/releases/download/v${FREEGLUT_VER}/freeglut-${FREEGLUT_VER}.tar.gz"
$freeglutDir = "freeglut-${FREEGLUT_VER}"

Download-File -Url $freeglutUrl -OutputPath $freeglutArchive
if (!(Test-Path $freeglutDir)) {
    Extract-Archive -ArchivePath $freeglutArchive
}

# Apply patches from patches/ directory if they exist
$patchesDir = Join-Path $SCRIPT_DIR "patches"
if (Test-Path $patchesDir) {
    Write-Host "Applying FreeGLUT patches..." -ForegroundColor Yellow
    $freeglutSrcDir = Join-Path $freeglutDir "src"
    Get-ChildItem $patchesDir -File | ForEach-Object {
        $targetFile = Join-Path $freeglutSrcDir $_.Name
        if (Test-Path $targetFile) {
            Write-Host "Patching $($_.Name)..." -ForegroundColor Cyan
            Copy-Item $_.FullName $targetFile -Force
        }
    }
}

if (!(Test-BuildComplete -Directory $freeglutDir)) {
    Set-Location $freeglutDir
    $buildDir = "build"
    if (!(Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir | Out-Null
    }
    Set-Location $buildDir
    
    & cmake -DCMAKE_INSTALL_PREFIX="..\install" -DFREEGLUT_BUILD_STATIC_LIBS=ON -DFREEGLUT_BUILD_SHARED_LIBS=ON -A x64 ..
    if ($LASTEXITCODE -ne 0) { Write-Error "CMake configuration failed for FreeGLUT"; exit 1 }
    
    & cmake --build . --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for FreeGLUT"; exit 1 }
    
    & cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { Write-Error "Install failed for FreeGLUT"; exit 1 }
    
    Set-Location ".."
    Set-BuildComplete -Directory "."
    Set-Location ".."
}

# Note: SWIG is not needed for Windows build and will be handled separately

# Return to script directory
Set-Location $SCRIPT_DIR

# Get Python paths for user reference
$pythonInclude = Join-Path $pythonDir "include"
$pythonLibs = Join-Path $pythonDir "libs"

Write-Host "Required environment variables (set these if needed):" -ForegroundColor Green
Write-Host "  SWIG_DIR: (if using SWIG)" -ForegroundColor Yellow
Write-Host "  PYTHON_INCLUDE: $pythonInclude" -ForegroundColor Yellow
Write-Host "  PYTHON_LIB: $pythonLibs" -ForegroundColor Yellow

# Copy required DLLs to DeepMimicCore directory for runtime
Write-Host "Copying runtime DLLs to DeepMimicCore directory..." -ForegroundColor Cyan
$deepMimicCoreDir = Join-Path $SCRIPT_DIR "DeepMimicCore"

# Copy GLEW DLL
$glewDll = Join-Path $LIBS_DIR "${glewDir}\bin\Release\x64\glew32.dll"
if (Test-Path $glewDll) {
    Copy-Item $glewDll $deepMimicCoreDir -Force
    Write-Host "Copied glew32.dll" -ForegroundColor Green
} else {
    Write-Warning "glew32.dll not found at $glewDll"
}

# Copy FreeGLUT DLL
$freeglutDll = Join-Path $LIBS_DIR "${freeglutDir}\install\bin\freeglut.dll"
if (Test-Path $freeglutDll) {
    Copy-Item $freeglutDll $deepMimicCoreDir -Force
    Write-Host "Copied freeglut.dll" -ForegroundColor Green
} else {
    Write-Warning "freeglut.dll not found at $freeglutDll"
}

# Environment setup complete - Manual Visual Studio configuration required
Write-Host "Environment setup complete. Now configure Visual Studio manually..." -ForegroundColor Cyan

Write-Host "Dependencies setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS - Manual Visual Studio Build:" -ForegroundColor Red
Write-Host ""
Write-Host "1. Open DeepMimicCore\DeepMimicCore.sln in Visual Studio" -ForegroundColor Yellow
Write-Host "2. Select the 'x64' configuration from the configuration manager" -ForegroundColor Yellow
Write-Host "3. Build DeepMimicCore project with the 'Release_Swig' configuration" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: Include and library paths are configured using relative paths in the project." -ForegroundColor Cyan
Write-Host ""
Write-Host "After successful build:" -ForegroundColor Green
Write-Host "• Activate Python environment: .\py\Scripts\Activate.ps1" -ForegroundColor Yellow
Write-Host "• Run DeepMimic: python DeepMimic.py --arg_file args\run_humanoid3d_spinkick_args.txt" -ForegroundColor Yellow
Write-Host "• Train policies: python mpi_run.py --arg_file args\train_humanoid3d_spinkick_args.txt --num_workers 4" -ForegroundColor Yellow 