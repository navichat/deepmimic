#!/usr/bin/env python3
"""
BVH to DeepMimic - Fixed to match existing format (36 values per frame)
"""

import numpy as np
import json
import os
import math
import argparse
import multiprocessing as mp
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from concurrent.futures import ProcessPoolExecutor, as_completed

class BVHParser:
    """Parse BVH files and extract skeletal structure and motion data"""

    def __init__(self):
        self.joints = {}
        self.joint_order = []
        self.channels = []
        self.frames = []
        self.frame_time = 0.0
        self.num_frames = 0

    def parse(self, bvh_file: str) -> Dict:
        """Parse BVH file and return structured data"""
        with open(bvh_file, 'r') as f:
            lines = f.readlines()

        hierarchy_end = self._parse_hierarchy(lines)
        self._parse_motion(lines[hierarchy_end:])

        return {
            'joints': self.joints,
            'joint_order': self.joint_order,
            'channels': self.channels,
            'frames': self.frames,
            'frame_time': self.frame_time,
            'num_frames': self.num_frames
        }

    def _parse_hierarchy(self, lines: List[str]) -> int:
        """Parse the HIERARCHY section"""
        joint_stack = []
        current_joint = None
        line_idx = 0

        for i, line in enumerate(lines):
            line = line.strip()

            if line.startswith('HIERARCHY'):
                continue
            elif line.startswith('MOTION'):
                line_idx = i
                break
            elif line.startswith('ROOT') or line.startswith('JOINT'):
                parts = line.split()
                joint_name = parts[1]
                current_joint = {
                    'name': joint_name,
                    'parent': joint_stack[-1] if joint_stack else None,
                    'children': [],
                    'offset': [0.0, 0.0, 0.0],
                    'channels': []
                }

                if joint_stack:
                    self.joints[joint_stack[-1]]['children'].append(joint_name)

                self.joints[joint_name] = current_joint
                self.joint_order.append(joint_name)
                joint_stack.append(joint_name)

            elif line.startswith('End Site'):
                end_name = f"{current_joint['name']}_End"
                end_joint = {
                    'name': end_name,
                    'parent': current_joint['name'],
                    'children': [],
                    'offset': [0.0, 0.0, 0.0],
                    'channels': []
                }
                current_joint['children'].append(end_name)
                self.joints[end_name] = end_joint
                joint_stack.append(end_name)

            elif line.startswith('OFFSET'):
                parts = line.split()
                offset = [float(parts[1]), float(parts[2]), float(parts[3])]
                self.joints[joint_stack[-1]]['offset'] = offset

            elif line.startswith('CHANNELS'):
                parts = line.split()
                num_channels = int(parts[1])
                channel_names = parts[2:2+num_channels]

                joint_name = joint_stack[-1]
                self.joints[joint_name]['channels'] = channel_names

                for channel in channel_names:
                    self.channels.append(f"{joint_name}_{channel}")

            elif line.startswith('}'):
                if joint_stack:
                    joint_stack.pop()

        return line_idx

    def _parse_motion(self, motion_lines: List[str]):
        """Parse the MOTION section"""
        for i, line in enumerate(motion_lines):
            line = line.strip()

            if line.startswith('Frames:'):
                self.num_frames = int(line.split(':')[1].strip())
            elif line.startswith('Frame Time:'):
                self.frame_time = float(line.split(':')[1].strip())
            elif line and not line.startswith('MOTION'):
                values = [float(x) for x in line.split()]
                self.frames.append(values)

class BVHToDeepMimicConverter:
    """Convert BVH data to DeepMimic format - EXACTLY 36 values per frame"""

    def __init__(self):
        # Target: 36 values per frame (35 DOF + time)
        # Format: [time, root_pos(3), root_rot(4), joint_rotations(28)]

        self.joint_mapping = {
            'Hips': 'root',
            'Spine': 'chest',
            'Neck': 'neck',
            'RightUpLeg': 'right_hip',
            'RightLeg': 'right_knee',
            'RightFoot': 'right_ankle',
            'RightShoulder': 'right_shoulder',
            'RightArm': 'right_elbow',
            'LeftUpLeg': 'left_hip',
            'LeftLeg': 'left_knee',
            'LeftFoot': 'left_ankle',
            'LeftShoulder': 'left_shoulder',
            'LeftArm': 'left_elbow'
        }

        # Based on 35 DOF total: 7 (root) + 28 (joints)
        # This suggests 28/4 = 7 joints with quaternions OR mixed format
        self.joint_config = [
            ('root', 7),        # 3 pos + 4 quat = 7
            ('chest', 4),       # 4 quat = 4
            ('neck', 3),        # 3 euler = 3
            ('right_hip', 3),   # 3 euler = 3
            ('right_knee', 1),  # 1 revolute = 1
            ('right_ankle', 3), # 3 euler = 3
            ('right_shoulder', 3), # 3 euler = 3
            ('right_elbow', 1), # 1 revolute = 1
            ('left_hip', 3),    # 3 euler = 3
            ('left_knee', 1),   # 1 revolute = 1
            ('left_ankle', 3),  # 3 euler = 3
            ('left_shoulder', 3), # 3 euler = 3
            ('left_elbow', 1)   # 1 revolute = 1
        ]
        # Total: 7 + 4 + 3 + 3 + 1 + 3 + 3 + 1 + 3 + 1 + 3 + 3 + 1 = 35 DOF + 1 time = 36

    def convert(self, bvh_data: Dict, output_file: str,
                loop: bool = True, fps: int = 30) -> Dict:
        """Convert BVH data to DeepMimic format"""

        # Resample to target FPS
        resampled_frames = self._resample_frames(
            bvh_data['frames'],
            bvh_data['frame_time'],
            1.0/fps
        )

        # Convert frames to DeepMimic format
        deepmimic_frames = []
        for i, frame_data in enumerate(resampled_frames):
            dm_frame = self._convert_frame(frame_data, bvh_data)
            if dm_frame is not None:
                dm_frame[0] = i * (1.0/fps)  # Set time
                deepmimic_frames.append(dm_frame)

        # Verify frame size
        if deepmimic_frames:
            frame_size = len(deepmimic_frames[0])
            print(f"Generated frame size: {frame_size} (target: 36)")

            if frame_size != 36:
                print(f"ERROR: Frame size mismatch! Expected 36, got {frame_size}")
                print(f"DOF breakdown:")
                running_total = 1  # time
                for joint_name, dof in self.joint_config:
                    print(f"  {joint_name}: {dof} DOF")
                    running_total += dof
                print(f"  Total: {running_total}")

                # Pad or truncate to exactly 36
                for frame in deepmimic_frames:
                    if len(frame) < 36:
                        frame.extend([0.0] * (36 - len(frame)))
                    elif len(frame) > 36:
                        frame[:] = frame[:36]

        # Create DeepMimic motion data
        motion_data = {
            "Loop": "wrap" if loop else "none",
            "Frames": deepmimic_frames
        }

        # Save to JSON
        with open(output_file, 'w') as f:
            json.dump(motion_data, f, indent=2)

        print(f"Converted {len(deepmimic_frames)} frames to {output_file}")
        print(f"Frame format: {len(deepmimic_frames[0]) if deepmimic_frames else 0} values per frame")
        return motion_data

    def _resample_frames(self, frames: List[List[float]],
                        original_dt: float, target_dt: float) -> List[List[float]]:
        """Resample motion data to target frame rate"""
        if abs(original_dt - target_dt) < 1e-6:
            return frames

        original_times = np.arange(len(frames)) * original_dt
        target_times = np.arange(0, original_times[-1], target_dt)

        resampled_frames = []
        for target_time in target_times:
            if target_time <= original_times[0]:
                resampled_frames.append(frames[0])
            elif target_time >= original_times[-1]:
                resampled_frames.append(frames[-1])
            else:
                idx = np.searchsorted(original_times, target_time) - 1
                t0, t1 = original_times[idx], original_times[idx + 1]
                alpha = (target_time - t0) / (t1 - t0)

                frame0, frame1 = frames[idx], frames[idx + 1]
                interpolated = []
                for v0, v1 in zip(frame0, frame1):
                    interpolated.append(v0 + alpha * (v1 - v0))
                resampled_frames.append(interpolated)

        return resampled_frames

    def _convert_frame(self, frame_data: List[float], bvh_data: Dict) -> Optional[List[float]]:
        """Convert single BVH frame to DeepMimic format - EXACTLY 36 values"""
        try:
            dm_frame = [0.0]  # Time

            # Root position (3 DOF)
            root_pos = frame_data[0:3] if len(frame_data) >= 3 else [0.0, 0.0, 0.0]
            dm_frame.extend(root_pos)

            # Root rotation as quaternion (4 DOF)
            root_rot_euler = frame_data[3:6] if len(frame_data) >= 6 else [0.0, 0.0, 0.0]
            root_quat = self._euler_to_quaternion(root_rot_euler)
            dm_frame.extend(root_quat)

            # Process each joint
            for joint_name, dof_count in self.joint_config[1:]:  # Skip root
                bvh_joint = self._find_bvh_joint(joint_name, bvh_data)

                if dof_count == 4:  # Quaternion
                    if bvh_joint and bvh_joint in bvh_data['joints']:
                        euler_rot = self._extract_joint_rotation(bvh_joint, frame_data, bvh_data)
                        quat = self._euler_to_quaternion([math.degrees(x) for x in euler_rot])
                        dm_frame.extend(quat)
                    else:
                        dm_frame.extend([0.0, 0.0, 0.0, 1.0])  # Identity quaternion

                elif dof_count == 3:  # Euler angles
                    if bvh_joint and bvh_joint in bvh_data['joints']:
                        euler_rot = self._extract_joint_rotation(bvh_joint, frame_data, bvh_data)
                        dm_frame.extend(euler_rot)
                    else:
                        dm_frame.extend([0.0, 0.0, 0.0])

                elif dof_count == 1:  # Single axis
                    if bvh_joint and bvh_joint in bvh_data['joints']:
                        rotation = self._extract_single_axis_rotation(bvh_joint, frame_data, bvh_data)
                        dm_frame.append(rotation)
                    else:
                        dm_frame.append(0.0)

            # Ensure exactly 36 values
            while len(dm_frame) < 36:
                dm_frame.append(0.0)

            if len(dm_frame) > 36:
                dm_frame = dm_frame[:36]

            return dm_frame

        except Exception as e:
            print(f"Error converting frame: {e}")
            return None

    def _extract_joint_rotation(self, joint_name: str, frame_data: List[float], bvh_data: Dict) -> List[float]:
        """Extract 3DOF rotation for joints"""
        joint_channels = bvh_data['joints'][joint_name]['channels']
        euler_rot = [0.0, 0.0, 0.0]

        for i, channel in enumerate(['Xrotation', 'Yrotation', 'Zrotation']):
            if channel in joint_channels:
                channel_idx = self._get_channel_index(joint_name, channel, bvh_data)
                if 0 <= channel_idx < len(frame_data):
                    euler_rot[i] = math.radians(frame_data[channel_idx])

        return euler_rot

    def _extract_single_axis_rotation(self, joint_name: str, frame_data: List[float], bvh_data: Dict) -> float:
        """Extract single axis rotation"""
        joint_channels = bvh_data['joints'][joint_name]['channels']

        for channel in ['Xrotation', 'Yrotation', 'Zrotation']:
            if channel in joint_channels:
                channel_idx = self._get_channel_index(joint_name, channel, bvh_data)
                if 0 <= channel_idx < len(frame_data):
                    return math.radians(frame_data[channel_idx])

        return 0.0

    def _find_bvh_joint(self, dm_joint: str, bvh_data: Dict) -> Optional[str]:
        """Find corresponding BVH joint"""
        # Direct mapping
        for bvh_joint, dm_mapped in self.joint_mapping.items():
            if dm_mapped == dm_joint and bvh_joint in bvh_data['joints']:
                return bvh_joint

        # Fuzzy matching
        for bvh_joint in bvh_data['joints']:
            bvh_lower = bvh_joint.lower().replace('_', '').replace(' ', '')
            dm_lower = dm_joint.lower().replace('_', '').replace(' ', '')
            if dm_lower in bvh_lower or bvh_lower in dm_lower:
                return bvh_joint

        return None

    def _get_channel_index(self, joint_name: str, channel: str, bvh_data: Dict) -> int:
        """Get global channel index"""
        idx = 0
        for joint in bvh_data['joint_order']:
            if joint == joint_name:
                joint_channels = bvh_data['joints'][joint]['channels']
                if channel in joint_channels:
                    return idx + joint_channels.index(channel)
                break
            idx += len(bvh_data['joints'][joint]['channels'])
        return -1

    def _euler_to_quaternion(self, euler: List[float]) -> List[float]:
        """Convert Euler angles (degrees) to quaternion [x, y, z, w]"""
        roll = math.radians(euler[0])
        pitch = math.radians(euler[1])
        yaw = math.radians(euler[2])

        cy = math.cos(yaw * 0.5)
        sy = math.sin(yaw * 0.5)
        cp = math.cos(pitch * 0.5)
        sp = math.sin(pitch * 0.5)
        cr = math.cos(roll * 0.5)
        sr = math.sin(roll * 0.5)

        w = cr * cp * cy + sr * sp * sy
        x = sr * cp * cy - cr * sp * sy
        y = cr * sp * cy + sr * cp * sy
        z = cr * cp * sy - sr * sp * cy

        return [x, y, z, w]

def copy_existing_format(reference_file: str, bvh_file: str, output_file: str, fps: int = 30):
    """Copy the exact format from a working motion file"""

    # Load reference motion file
    with open(reference_file, 'r') as f:
        ref_data = json.load(f)

    ref_frames = ref_data['Frames']
    if not ref_frames:
        print("Reference file has no frames")
        return

    frame_size = len(ref_frames[0])
    print(f"Reference frame size: {frame_size}")

    # Parse BVH
    parser = BVHParser()
    bvh_data = parser.parse(bvh_file)

    # Create frames with exact same structure
    new_frames = []
    target_dt = 1.0 / fps

    for i, bvh_frame in enumerate(bvh_data['frames']):
        # Create frame with exact size as reference
        dm_frame = [0.0] * frame_size

        # Set time
        dm_frame[0] = i * target_dt

        # Copy root position if available
        if len(bvh_frame) >= 3:
            dm_frame[1:4] = bvh_frame[0:3]

        # Convert root rotation to quaternion
        if len(bvh_frame) >= 6:
            root_rot = bvh_frame[3:6]
            quat = BVHToDeepMimicConverter()._euler_to_quaternion(root_rot)
            dm_frame[4:8] = quat
        else:
            dm_frame[4:8] = [0.0, 0.0, 0.0, 1.0]

        # Fill remaining values (simplified approach)
        for j in range(8, frame_size):
            if j - 8 < len(bvh_frame) - 6:
                dm_frame[j] = math.radians(bvh_frame[j - 8 + 6])
            else:
                dm_frame[j] = 0.0

        new_frames.append(dm_frame)

    # Create motion data
    motion_data = {
        "Loop": ref_data.get("Loop", "wrap"),
        "Frames": new_frames
    }

    # Save
    with open(output_file, 'w') as f:
        json.dump(motion_data, f, indent=2)

    print(f"Generated {len(new_frames)} frames with {frame_size} values each")

def main():
    parser = argparse.ArgumentParser(description='BVH to DeepMimic - Fixed format (36 values)')
    parser.add_argument('input', nargs='?', help='BVH file or directory')
    parser.add_argument('--output-dir', default='training_data', help='Output directory')
    parser.add_argument('--fps', type=int, default=30, help='Target frame rate')
    parser.add_argument('--no-loop', action='store_true', help='Disable looping')
    parser.add_argument('--analyze', action='store_true', help='Analyze existing files')
    parser.add_argument('--reference', help='Reference motion file to copy format from')

    args = parser.parse_args()

    if args.analyze:
        print("=== ANALYZING EXISTING MOTION FILES ===")
        motion_dir = Path("data/motions")
        if motion_dir.exists():
            for motion_file in motion_dir.glob("*.json"):
                try:
                    with open(motion_file, 'r') as f:
                        data = json.load(f)
                    frames = data['Frames']
                    if frames:
                        print(f"{motion_file.name}: {len(frames[0])} values per frame")
                        print(f"  Loop: {data.get('Loop', 'unknown')}")
                        print(f"  Frames: {len(frames)}")
                        print(f"  Sample: {frames[0][:10]}...")
                        print("-" * 40)
                except Exception as e:
                    print(f"Error: {e}")
        return

    if not args.input:
        print("Error: input required")
        return

    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)

    if args.reference:
        # Use reference file format
        output_file = output_dir / f"{input_path.stem}_motion.json"
        copy_existing_format(args.reference, str(input_path), str(output_file), args.fps)
    else:
        # Use converter
        parser_obj = BVHParser()
        converter = BVHToDeepMimicConverter()

        bvh_data = parser_obj.parse(str(input_path))
        output_file = output_dir / f"{input_path.stem}_motion.json"

        converter.convert(bvh_data, str(output_file), loop=not args.no_loop, fps=args.fps)

    print(f"Output: {output_file}")

if __name__ == "__main__":
    main()
