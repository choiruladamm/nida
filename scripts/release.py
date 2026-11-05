#!/usr/bin/env python3
"""Personal Release candidates, verified DMGs and explicit Stable promotion."""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
STATE = Path.home() / 'Library/Application Support/NidaReleases'
TARGET = Path('/Applications/Nida.app')
BUNDLE = 'dev.choiruladam.nida'


def command(*args, **kwargs):
    return subprocess.check_output([str(a) for a in args], text=True, **kwargs).strip()


def tree_hash(app):
    digest = hashlib.sha256()
    for file in sorted(app.rglob('*')):
        digest.update(str(file.relative_to(app)).encode() + b'\0')
        digest.update(str(stat.S_IMODE(file.lstat().st_mode)).encode() + b'\0')
        if file.is_symlink():
            digest.update(b'link\0' + os.readlink(file).encode())
        elif file.is_file():
            digest.update(b'file\0' + file.read_bytes())
    return digest.hexdigest()


def verify_app(app, sha=None):
    if app.is_symlink() or not app.is_dir():
        raise RuntimeError('Expected a real app directory: ' + str(app))
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE or info.get('CFBundleExecutable') != 'Nida':
        raise RuntimeError('Candidate is not Nida Stable')
    if not os.access(app / 'Contents/MacOS/Nida', os.X_OK):
        raise RuntimeError('Stable executable is not executable')
    if sha is not None and info.get('NidaSourceCommit') != sha:
        raise RuntimeError('Candidate source SHA mismatch')
    command('codesign', '--verify', '--deep', '--strict', app, stderr=subprocess.STDOUT)
    entitlements = command('codesign', '-d', '--entitlements', ':-', app, stderr=subprocess.DEVNULL)
    if not plistlib.loads(entitlements.encode()).get('com.apple.security.app-sandbox'):
        raise RuntimeError('Stable sandbox entitlement missing')
    return info


def require_clean():
    if command('git', '-C', REPO, 'status', '--porcelain'):
        raise RuntimeError('Commit or stash changes first; no uncommitted source is packaged')


def require_ci(sha):
    repository = command('gh', 'repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner', cwd=REPO)
    response = json.loads(command('gh', 'api', f'repos/{repository}/actions/workflows/ci.yml/runs?event=push&head_sha={sha}&per_page=100'))
    runs = [r for r in response['workflow_runs'] if r['head_sha'] == sha and r['head_branch'] == 'main']
    if not runs or max(runs, key=lambda r: r['run_number'])['conclusion'] != 'success':
        raise RuntimeError('Latest main CI for this exact SHA is missing, pending or failed; Stable untouched')


def candidate(sha, state):
    folder = state / 'candidates' / sha
    app = folder / 'Nida.app'
    if folder.exists():
        receipt = json.loads((folder / 'receipt.json').read_text())
        verify_app(app, sha)
        if receipt['sha'] != sha or receipt['treeHash'] != tree_hash(app):
            raise RuntimeError('Cached candidate changed; refusing to reuse it')
        return app
    folder.parent.mkdir(parents=True, exist_ok=True)
    log = state / 'last-build.log'
    with tempfile.TemporaryDirectory(prefix='nida-source-') as source, tempfile.TemporaryDirectory(dir=folder.parent) as staging:
        archive = subprocess.check_output(['git', '-C', str(REPO), 'archive', sha])
        subprocess.run(['tar', '-xf', '-', '-C', source], input=archive, check=True)
        derived = state / 'DerivedData'
        with log.open('w') as output:
            for args in [
                ['make', 'test', 'BUILD_DIR=' + str(derived)],
                ['make', 'build', 'CONFIGURATION=Release', 'BUILD_DIR=' + str(derived), 'SOURCE_SHA=' + sha],
            ]:
                print('Running ' + ' '.join(args[:3]) + '; log: ' + str(log), flush=True)
                subprocess.run(args, cwd=source, stdout=output, stderr=subprocess.STDOUT, check=True)
        staged = Path(staging) / 'Nida.app'
        shutil.copytree(derived / 'Build/Products/Release/Nida.app', staged, symlinks=True)
        info = verify_app(staged, sha)
        receipt = {'sha': sha, 'treeHash': tree_hash(staged), 'version': info['CFBundleShortVersionString'], 'build': str(info['CFBundleVersion'])}
        (Path(staging) / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        Path(staging).rename(folder)
    return app


def login_record():
    dump = command('sfltool', 'dumpbtm')
    match = re.search(r'Records for UID ' + str(os.getuid()) + r' :.*?(?=Records for UID|\Z)', dump, re.S)
    if not match:
        raise RuntimeError('Cannot inspect this user\'s login items; refusing installation')
    for block in re.split(r'\n\s*#\d+:', match.group()):
        if re.search(r'Bundle Identifier:\s*' + re.escape(BUNDLE) + r'\s*$', block, re.M):
            url = re.search(r'^\s*URL:\s*(.+)$', block, re.M)
            disposition = re.search(r'Disposition:\s*\[([^]]*)\]', block)
            if not url or not disposition:
                raise RuntimeError('Unrecognized Nida login record')
            flags = set(disposition[1].replace(',', '').split())
            return {'enabled': 'enabled' in flags and 'allowed' in flags, 'url': url[1].strip()}
    return {'enabled': False, 'url': None}


def restore_login(target, before):
    info = plistlib.loads((target / 'Contents/Info.plist').read_bytes())
    if str(info.get('NidaReleaseMaintenance')) != '1':
        if before['enabled']:
            raise RuntimeError('Previous app restored; re-enable login from its Settings if necessary')
        return
    flag = '--restore-login-enabled' if before['enabled'] else '--login-status'
    report = json.loads(command(target / 'Contents/MacOS/Nida', flag, timeout=30))
    after = login_record()
    if report['hasError'] or after['enabled'] != before['enabled']:
        raise RuntimeError('Login registration was not preserved; check System Settings')
    if before['enabled'] and (report['status'] != 'enabled' or after['url'] != str(target)):
        raise RuntimeError('Login item does not point to the installed app')


def stable_pids(target):
    result = []
    for line in command('ps', '-ww', '-axo', 'pid=,comm=').splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and Path(fields[1]).name == 'Nida':
            if fields[1] != str(target / 'Contents/MacOS/Nida'):
                raise RuntimeError('Quit the other build-folder Nida instance before promotion')
            result.append(int(fields[0]))
    return result


def stop_stable(target):
    for pid in stable_pids(target):
        os.kill(pid, signal.SIGTERM)
    for _ in range(30):
        if not stable_pids(target):
            return
        time.sleep(.1)
    raise RuntimeError('Stable did not stop; refusing to replace a running app')


def launch_stable(target):
    subprocess.run(['open', str(target)], check=True)
    for _ in range(50):
        if len(stable_pids(target)) == 1:
            time.sleep(1)
            if len(stable_pids(target)) == 1:
                return
        time.sleep(.2)
    raise RuntimeError('Installed Stable did not stay running')


def install(app, target, state):
    verify_app(app)
    if target.is_symlink():
        raise RuntimeError('Installed app must not be a symlink')
    if target.exists() and tree_hash(app) == tree_hash(target):
        print('Identical candidate already installed; no restart')
        return
    before = login_record()
    stable_pids(target)
    # Keep recovery directories if restoration itself fails; never discard the last good app.
    stage = Path(tempfile.mkdtemp(prefix='.nida-install-', dir=target.parent))
    saved = Path(tempfile.mkdtemp(prefix='.backup-', dir=state))
    cleanup = True
    stopped = old_moved = new_placed = login_touched = False
    try:
        shutil.copytree(app, stage / 'new.app', symlinks=True)
        verify_app(stage / 'new.app')
        if tree_hash(app) != tree_hash(stage / 'new.app'):
            raise RuntimeError('Staged copy differs from verified candidate')
        if target.exists():
            verify_app(target)
            shutil.copytree(target, saved / 'Nida.app', symlinks=True)
            verify_app(saved / 'Nida.app')
        try:
            stop_stable(target)
            stopped = True
            if target.exists():
                target.rename(stage / 'old.app')
                old_moved = True
            (stage / 'new.app').rename(target)
            new_placed = True
            login_touched = True
            restore_login(target, before)
            launch_stable(target)
            previous = state / 'previous.app'
            if previous.exists():
                previous.rename(saved / 'older.app')
            try:
                if (saved / 'Nida.app').exists():
                    (saved / 'Nida.app').rename(previous)
            except BaseException:
                if (saved / 'older.app').exists():
                    (saved / 'older.app').rename(previous)
                raise
        except BaseException as failure:
            if stopped:
                cleanup = False
                stop_stable(target)
                if new_placed and target.exists():
                    target.rename(stage / 'failed.app')
                if old_moved:
                    (stage / 'old.app').rename(target)
                if target.exists():
                    launch_stable(target)
                    if login_touched:
                        try:
                            restore_login(target, before)
                        except Exception as repair:
                            print('LOGIN CHECK: ' + str(repair), file=sys.stderr)
                cleanup = True
            raise RuntimeError('Promotion failed; previous installation restored where available: ' + str(failure)) from failure
    finally:
        if cleanup:
            shutil.rmtree(stage)
            shutil.rmtree(saved)
        else:
            print('RECOVERY COPIES RETAINED: ' + str(stage) + ' and ' + str(saved), file=sys.stderr)


def dmg(app, state):
    info = verify_app(app)
    sha = info['NidaSourceCommit']
    output = state / 'packages' / f'Nida-{info["CFBundleShortVersionString"]}-build{info["CFBundleVersion"]}-{sha[:12]}.dmg'
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.nida-dmg-', dir=output.parent) as temp:
        staged_dmg = Path(temp) / 'Nida.dmg'
        root = Path(temp) / 'volume'
        root.mkdir()
        shutil.copytree(app, root / 'Nida.app', symlinks=True)
        (root / 'Applications').symlink_to('/Applications')
        command('hdiutil', 'create', '-volname', 'Nida', '-srcfolder', root, '-format', 'UDZO', staged_dmg)
        mount = Path(temp) / 'mount'
        mount.mkdir()
        command('hdiutil', 'attach', '-nobrowse', '-readonly', '-mountpoint', mount, staged_dmg)
        try:
            verify_app(mount / 'Nida.app', sha)
            if tree_hash(mount / 'Nida.app') != tree_hash(app) or os.readlink(mount / 'Applications') != '/Applications':
                raise RuntimeError('Mounted installer differs from candidate')
        finally:
            command('hdiutil', 'detach', mount)
        staged_dmg.replace(output)
    output.with_suffix('.dmg.sha256').write_text(hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n')
    print(output)
    return output


@contextlib.contextmanager
def locked(state):
    if state.is_symlink():
        raise RuntimeError('Release state must not be a symlink')
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = state / '.lock'
    lock.mkdir()  # Fail instead of racing another promotion/package operation.
    try:
        yield
    finally:
        lock.rmdir()


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ['dmg', 'promote', 'rollback']:
        raise RuntimeError('Usage: release.py dmg|promote|rollback')
    action = sys.argv[1]
    with locked(STATE):
        if action == 'rollback':
            install(STATE / 'previous.app', TARGET, STATE)
            return
        require_clean()
        if action == 'promote':
            subprocess.run(['git', '-C', str(REPO), 'fetch', 'origin', 'main'], check=True)
            sha = command('git', '-C', REPO, 'rev-parse', 'origin/main')
            require_ci(sha)
        else:
            sha = command('git', '-C', REPO, 'rev-parse', 'HEAD')
        app = candidate(sha, STATE)
        if action == 'dmg':
            dmg(app, STATE)
        else:
            install(app, TARGET, STATE)
            print('Installed main ' + sha)


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
