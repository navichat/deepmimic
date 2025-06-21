from pathlib import Path
from bvhtomimic import BvhConverter

def main():
	converter = BvhConverter('./bvh_settings.json')
	motions_dir = Path('data/motions')

	if not motions_dir.exists():
		print('Error: data/motions directory not found')
		return
	
	bvh_files = list(motions_dir.glob('**/*.bvh'))
	if not bvh_files:
		print('No BVH files found in data/motions/')
		return
	
	print(f'Found {len(bvh_files)} BVH files to convert')
	
	for bvh_file in bvh_files:
		json_file = bvh_file.with_suffix('.json')
		
		with open(str(json_file), 'w') as f:
			f.write(converter.convertBvhFile(str(bvh_file), loop=True))


if __name__ == '__main__':
	main()