import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import json
import tempfile

spec = importlib.util.spec_from_file_location('selection', Path(__file__).with_name('select-build-info.py'))
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)


class SelectionTest(unittest.TestCase):
    def fixture(self):
        imports = {'contracts/A.sol': ['lib/B.sol'], 'lib/B.sol': ['test/Dependency.sol'],
                   'test/Dependency.sol': ['contracts/A.sol'], 'test/Test.sol': []}
        sources = {name: {'id': index, 'ast': {'nodes': [
            {'nodeType': 'ImportDirective', 'absolutePath': dependency} for dependency in dependencies]}}
            for index, (name, dependencies) in enumerate(imports.items())}
        return {'input': {'sources': {name: {'content': name} for name in sources}},
                'output': {'sources': sources, 'contracts': {
                    name: {'Contract': {'evm': {'bytecode': {'object': '1234', 'sourceMap': '1:2:3'}}}}
                    for name in sources}},
                'source_id_to_path': {str(value['id']): name for name, value in sources.items()}}

    def test_import_closure_keeps_ids_and_bytecode(self):
        original = self.fixture()
        result = selection.select(copy.deepcopy(original), Path('/project'), Path('/project/contracts'))
        expected = {'contracts/A.sol', 'lib/B.sol', 'test/Dependency.sol'}
        self.assertEqual(set(result['input']['sources']), expected)
        for name in expected:
            self.assertEqual(result['output']['sources'][name], original['output']['sources'][name])
            self.assertEqual(result['output']['contracts'][name], original['output']['contracts'][name])
        self.assertEqual(set(result['source_id_to_path'].values()), expected)

    def test_file_target_and_unrelated_unit(self):
        result = selection.select(self.fixture(), Path('/project'), Path('/project/test/Test.sol'))
        self.assertEqual(set(result['output']['sources']), {'test/Test.sol'})
        self.assertIsNone(selection.select(self.fixture(), Path('/project'), Path('/project/other')))

    def test_project_config_multiple_units_and_original_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'foundry.toml').touch()
            (root / 'contracts').mkdir()
            build = root / 'custom-build-info'
            build.mkdir()
            original = json.dumps(self.fixture())
            for name in ['compiler-a.json', 'compiler-b.json']:
                (build / name).write_text(original)
            destination = root / 'selected'
            config = json.dumps({'src': 'contracts', 'out': 'custom-out',
                                 'build_info_path': str(build)}).encode()
            with patch.object(selection.sys, 'argv', ['select', str(root), str(destination)]), \
                 patch.object(selection.subprocess, 'check_output', return_value=config) as forge:
                selection.main()
            forge.assert_called_once_with(['forge', 'config', '--json', '--root', str(root)])
            self.assertEqual(len(list(destination.glob('*.json'))), 2)
            for path in build.glob('*.json'):
                self.assertEqual(path.read_text(), original)
                self.assertNotIn('test/Test.sol', json.loads((destination / path.name).read_text())['output']['sources'])

    def test_missing_import_fails(self):
        info = self.fixture()
        del info['output']['sources']['lib/B.sol']
        with self.assertRaisesRegex(ValueError, 'Imported source missing'):
            selection.select(info, Path('/project'), Path('/project/contracts'))


if __name__ == '__main__':
    unittest.main()
