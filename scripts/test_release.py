import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / 'state'
        self.state.mkdir()
        self.target = self.app('installed/Nida.app', 'old')
        self.new = self.app('candidate/Nida.app', 'new')
        self.read_login = release.login_record
        for name, value in [('verify_app', {}), ('stable_pids', [123]), ('stop_stable', None),
                            ('launch_stable', None), ('restore_login', None),
                            ('login_record', {'enabled': True, 'url': str(self.target)})]:
            mock = patch.object(release, name, return_value=value)
            setattr(self, name, mock.start())
            self.addCleanup(mock.stop)

    def app(self, path, value):
        folder = self.root / path
        (folder / 'Contents').mkdir(parents=True)
        (folder / 'Contents/value').write_text(value)
        return folder

    def value(self, app):
        return (app / 'Contents/value').read_text()

    def test_success_and_rollback_keep_one_previous_binary(self):
        release.install(self.new, self.target, self.state)
        self.assertEqual(self.value(self.target), 'new')
        self.assertEqual(self.value(self.state / 'previous.app'), 'old')
        release.install(self.state / 'previous.app', self.target, self.state)
        self.assertEqual(self.value(self.target), 'old')
        self.assertEqual(self.value(self.state / 'previous.app'), 'new')

    def test_invalid_candidate_does_not_stop_or_replace_stable(self):
        self.verify_app.side_effect = RuntimeError('bad signature')
        with self.assertRaises(RuntimeError):
            release.install(self.new, self.target, self.state)
        self.stop_stable.assert_not_called()
        self.assertEqual(self.value(self.target), 'old')

    def test_copy_failure_preserves_running_stable(self):
        with patch.object(release.shutil, 'copytree', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                release.install(self.new, self.target, self.state)
        self.stop_stable.assert_not_called()
        self.assertEqual(self.value(self.target), 'old')

    def test_startup_failure_restores_old_binary(self):
        self.launch_stable.side_effect = [RuntimeError('new crashed'), None]
        with self.assertRaises(RuntimeError):
            release.install(self.new, self.target, self.state)
        self.assertEqual(self.value(self.target), 'old')
        self.assertEqual(self.launch_stable.call_count, 2)

    def test_login_failure_restores_binary_and_enabled_intent(self):
        self.restore_login.side_effect = [RuntimeError('OS rejected registration'), None]
        with self.assertRaises(RuntimeError):
            release.install(self.new, self.target, self.state)
        self.assertEqual(self.value(self.target), 'old')
        self.assertTrue(self.restore_login.call_args.args[1]['enabled'])

    def test_failed_rollback_keeps_recovery_files(self):
        self.launch_stable.side_effect = RuntimeError('cannot launch')
        with self.assertRaises(RuntimeError):
            release.install(self.new, self.target, self.state)
        backups = list(self.state.glob('.backup-*/Nida.app'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(self.value(backups[0]), 'old')

    def test_failed_initial_rename_does_not_remove_old_target(self):
        original = Path.rename
        def rename(path, target):
            if path == self.target:
                raise OSError('rename denied')
            return original(path, target)
        with patch.object(Path, 'rename', rename):
            with self.assertRaises(RuntimeError):
                release.install(self.new, self.target, self.state)
        self.assertEqual(self.value(self.target), 'old')

    def test_same_candidate_does_not_restart_stable(self):
        release.install(self.target, self.target, self.state)
        self.stop_stable.assert_not_called()

    def test_missing_backup_and_symlink_are_rejected_before_stop(self):
        self.verify_app.side_effect = FileNotFoundError('backup missing')
        with self.assertRaises(FileNotFoundError):
            release.install(self.state / 'previous.app', self.target, self.state)
        self.stop_stable.assert_not_called()

    def test_symlink_target_is_never_replaced(self):
        link = self.root / 'linked.app'
        link.symlink_to(self.target, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            release.install(self.new, link, self.state)
        self.stop_stable.assert_not_called()
        self.assertEqual(self.value(self.target), 'old')

    def test_cached_candidate_tampering_is_rejected(self):
        sha = 'a' * 40
        folder = self.state / 'candidates' / sha
        app = self.app('state/candidates/' + sha + '/Nida.app', 'candidate')
        (folder / 'receipt.json').write_text(json.dumps({'sha': sha, 'treeHash': release.tree_hash(app)}))
        self.assertEqual(release.candidate(sha, self.state), app)
        (app / 'Contents/value').write_text('tampered')
        with self.assertRaises(RuntimeError): release.candidate(sha, self.state)
        self.stop_stable.assert_not_called()

    def test_icon_assets_cover_native_macos_sizes_and_dev_is_distinct(self):
        import struct
        for name in ['AppIcon', 'AppIconDev']:
            folder = release.REPO / 'Nida/Assets.xcassets' / (name + '.appiconset')
            catalog = json.loads((folder / 'Contents.json').read_text())
            self.assertEqual(len(catalog['images']), 10)
            for entry in catalog['images']:
                png = (folder / entry['filename']).read_bytes()
                expected = int(entry['size'].split('x')[0]) * int(entry['scale'][0])
                self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(struct.unpack('>II', png[16:24]), (expected, expected))
        root = release.REPO / 'Nida/Assets.xcassets'
        self.assertNotEqual((root / 'AppIcon.appiconset/icon_512x512@2x.png').read_bytes(),
                            (root / 'AppIconDev.appiconset/icon_512x512@2x.png').read_bytes())

    def test_ci_requires_latest_success_for_exact_main_sha(self):
        for conclusion in [None, 'failure', 'cancelled']:
            response = {'workflow_runs': [{'head_sha': 'abc', 'head_branch': 'main', 'run_number': 1, 'conclusion': 'success'},
                                           {'head_sha': 'abc', 'head_branch': 'main', 'run_number': 2, 'conclusion': conclusion}]}
            with patch.object(release, 'command', side_effect=['owner/repo', json.dumps(response)]):
                with self.assertRaises(RuntimeError): release.require_ci('abc')
        with patch.object(release, 'command', side_effect=['owner/repo', '{"workflow_runs": []}']):
            with self.assertRaises(RuntimeError): release.require_ci('abc')
        response = {'workflow_runs': [{'head_sha': 'abc', 'head_branch': 'main', 'run_number': 2, 'conclusion': 'success'}]}
        with patch.object(release, 'command', side_effect=['owner/repo', json.dumps(response)]):
            release.require_ci('abc')

    def test_dirty_source_and_concurrent_operation_refused(self):
        with patch.object(release, 'command', return_value=' M Nida.swift'):
            with self.assertRaises(RuntimeError): release.require_clean()
        with release.locked(self.state):
            with self.assertRaises(FileExistsError):
                with release.locked(self.state): pass
        self.assertFalse((self.state / '.lock').exists())

    def test_user_login_record_parsing_preserves_disabled_intent(self):
        dump = f'Records for UID {release.os.getuid()} : user\n #1:\n Bundle Identifier: {release.BUNDLE}\n URL: /Applications/Nida.app\n Disposition: [enabled, allowed, notified]\n'
        with patch.object(release, 'command', return_value=dump):
            self.assertTrue(self.read_login()['enabled'])
        with patch.object(release, 'command', return_value=dump.replace('enabled, allowed,', 'enabled,')):
            self.assertFalse(self.read_login()['enabled'])
        with patch.object(release, 'command', return_value='unknown format'):
            with self.assertRaises(RuntimeError): self.read_login()


if __name__ == '__main__':
    unittest.main()
