"""Select production sources and their imports without changing compiler output."""

import json
from pathlib import Path
import subprocess
import sys


def select(info, root, target):
    sources = info['output']['sources']
    pending = [name for name in sources
               if (root / name).resolve() == target
               or target in (root / name).resolve().parents]
    keep = set()
    while pending:
        name = pending.pop()
        if name in keep:
            continue
        if name not in sources:
            raise ValueError(f'Imported source missing from build-info: {name}')
        keep.add(name)
        pending.extend(node['absolutePath'] for node in sources[name]['ast']['nodes']
                       if node['nodeType'] == 'ImportDirective')
    if not keep:
        return None
    for container, key in [(info['input'], 'sources'), (info['output'], 'sources'),
                           (info['output'], 'contracts')]:
        container[key] = {name: value for name, value in container[key].items() if name in keep}
    if 'source_id_to_path' in info:
        info['source_id_to_path'] = {key: name for key, name in info['source_id_to_path'].items()
                                     if name in keep}
    return info


def main():
    target = Path(sys.argv[1]).resolve()
    start = target if target.is_dir() else target.parent
    root = next((path for path in [start, *start.parents]
                 if (path / 'foundry.toml').is_file()), None)
    if root is None:
        raise ValueError(f'No Foundry project found for {target}')
    config = json.loads(subprocess.check_output(['forge', 'config', '--json', '--root', str(root)]))
    source = root / (config.get('build_info_path') or str(Path(config['out']) / 'build-info'))
    destination = Path(sys.argv[2]).resolve()
    # A separate empty directory prevents stale units and protects the full build.
    destination.mkdir()
    if target == root:
        target = (root / config['src']).resolve()
    count = 0
    for path in sorted(source.glob('*.json')):
        info = select(json.loads(path.read_text()), root, target)
        if info is not None:
            (destination / path.name).write_text(json.dumps(info))
            count += 1
    if not count:
        raise ValueError(f'No build-info sources found for {target}')
    print(f'Selected {count} build-info unit(s) for Slither')


if __name__ == '__main__':
    main()
