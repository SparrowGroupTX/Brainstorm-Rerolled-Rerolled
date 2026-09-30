"""Freeze one tested runtime slice over the installed product, then verify deployment.

Explicit relative file arguments prevent unrelated in-progress work being installed.
Configuration and saves are excluded by install_advisor.ps1. No game process control.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
INSTALLED=Path('C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm')
NATIVE_BASE='Immolate-v2.16.dll'
SIDECAR=re.compile(r'Immolate-advisor-([0-9a-f]{64})\.dll')
VERSION_FIELDS={
    'Core/Brainstorm.lua':re.compile(rb'Brainstorm\.VERSION[ \t]*=[ \t]*"Brainstorm v(?P<version>[^"\r\n \t]+)[ \t]*"'),
    'steamodded_compat.lua':re.compile(rb'--- VERSION:[ \t]*(?P<version>[^ \t\r\n]+)'),
}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stamp_version(path,relative,version):
    """Change only the version value; preserve every other byte and no-op writes."""
    if not re.fullmatch(r'\d+\.\d+\.\d+-alpha',version):
        raise ValueError('Expected explicit alpha version')
    path=Path(path)
    original=path.read_bytes()
    matches=list(VERSION_FIELDS[relative].finditer(original))
    if not matches: raise ValueError(f'Missing version in {path}')
    if len(matches)!=1: raise ValueError(f'Ambiguous version in {path}')
    match=matches[0];replacement=version.encode('ascii')
    if match.group('version')==replacement: return False
    start,end=match.span('version')
    path.write_bytes(original[:start]+replacement+original[end:])
    return True


def contained(root,relative):
    if not isinstance(relative,str) or not relative or '\\' in relative or ':' in relative or relative.startswith('/') or '..' in relative.split('/'):
        raise ValueError('Expected a contained forward-slash relative path')
    path=(Path(root)/relative).resolve()
    path.relative_to(Path(root).resolve())
    if not path.is_file(): raise ValueError(f'Missing evidence file: {relative}')
    return path


def checked_hash(root,relative,expected):
    if not isinstance(expected,str) or not re.fullmatch('[0-9a-f]{64}',expected):
        raise ValueError('Expected a lowercase SHA256')
    path=contained(root,relative)
    if sha256(path)!=expected: raise ValueError(f'Evidence hash mismatch: {relative}')
    return path


def loader_name(core):
    matches=re.findall(r'Brainstorm\.NATIVE_FILE\s*=\s*["\']([^"\']+)["\']',core)
    if not matches: return NATIVE_BASE
    if len(matches)!=1 or not SIDECAR.fullmatch(matches[0]):
        raise ValueError('Expected one exact content-addressed native loader constant')
    if not re.search(r'library_name\s*=\s*Brainstorm\.NATIVE_FILE\b',core):
        raise ValueError('The tested Windows loader must use Brainstorm.NATIVE_FILE')
    return matches[0]


def requested_files(files):
    result=[]
    for supplied in files:
        relative=supplied.replace('\\','/')
        if not relative or relative.startswith('/') or ':' in relative or '..' in relative.split('/'):
            raise ValueError('Slice path escapes Brainstorm')
        if relative.lower()=='config.lua': raise ValueError('Configuration is never a runtime slice')
        if not (relative.endswith('.lua') or relative==NATIVE_BASE or SIDECAR.fullmatch(relative)):
            raise ValueError('Only explicit runtime Lua files or a verified native sidecar are accepted')
        if relative in result: raise ValueError('Repeated runtime slice file')
        result.append(relative)
    return result


def validate_native_evidence(path,files,root=ROOT):
    """Validate receipts only; never build, run a test, or load a DLL here."""
    manifest_bytes=Path(path).read_bytes()
    manifest=json.loads(manifest_bytes.decode('utf-8'))
    if manifest.get('schema')!=1 or manifest.get('kind')!='advisor_native_slice':
        raise ValueError('Expected advisor_native_slice evidence schema1')
    dll=manifest.get('dll') or {};relative=dll.get('path')
    natives=[name for name in files if name.endswith('.dll')]
    if len(natives)!=1 or relative!='Brainstorm/'+natives[0]:
        raise ValueError('Evidence must bind exactly the requested native artifact')
    binary=checked_hash(root,relative,dll.get('sha256'))
    sidecar=SIDECAR.fullmatch(natives[0])
    if sidecar and sidecar.group(1)!=dll['sha256']:
        raise ValueError('Native sidecar filename must contain the complete DLL SHA256')
    for field in ('sources','tests','runtime_files'):
        entries=manifest.get(field)
        if not isinstance(entries,dict) or not entries: raise ValueError(f'Missing {field} hashes')
        for rel,expected in entries.items(): checked_hash(root,rel,expected)
    runtime=manifest['runtime_files']
    if 'Core/Brainstorm.lua' not in files or 'Brainstorm/Core/Brainstorm.lua' not in runtime:
        raise ValueError('A native slice requires the explicitly tested Core loader')
    for rel in files:
        if rel.endswith('.lua') and 'Brainstorm/'+rel not in runtime:
            raise ValueError(f'Native companion Lua file lacks tested evidence: {rel}')
    core=contained(root,'Brainstorm/Core/Brainstorm.lua').read_text(encoding='utf-8')
    if loader_name(core)!=natives[0]: raise ValueError('Tested Core loader does not select the requested native artifact')
    validations=manifest.get('validation')
    if not isinstance(validations,list) or not validations: raise ValueError('Missing native validation receipts')
    for receipt in [manifest.get('build')]+validations:
        if not isinstance(receipt,dict) or receipt.get('status')!='complete' or type(receipt.get('exit_code')) is not int or receipt['exit_code']!=0:
            raise ValueError('Every admitted build/test receipt must be completed successfully')
        command=receipt.get('command')
        if not isinstance(command,list) or not command or any(not isinstance(x,str) or not x for x in command):
            raise ValueError('Receipt needs the exact command argument list')
        cap,elapsed=receipt.get('timeout_seconds'),receipt.get('elapsed_seconds')
        if any(type(v) not in (int,float) or not math.isfinite(v) for v in (cap,elapsed)) or cap<=0 or elapsed<0 or elapsed>cap:
            raise ValueError('Receipt must preserve a completed bounded execution time')
        log=receipt.get('log') or {};checked_hash(root,log.get('path'),log.get('sha256'))
    return {'manifest':manifest,'manifest_bytes':manifest_bytes,'manifest_sha256':hashlib.sha256(manifest_bytes).hexdigest(),
        'binary':binary,'native_file':natives[0]}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--version',required=True)
    p.add_argument('--native-evidence',type=Path,help='Completed build/test receipts bound to the exact native sidecar and tested Lua loader')
    p.add_argument('files',nargs='+')
    a=p.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+-alpha',a.version): p.error('Expected explicit alpha version')
    try: files=requested_files(a.files)
    except ValueError as error: p.error(str(error))
    installed=INSTALLED
    natives=[rel for rel in files if rel.endswith('.dll')]
    if bool(natives)!=bool(a.native_evidence): p.error('An explicit native artifact and --native-evidence must be supplied together')
    evidence=validate_native_evidence(a.native_evidence,files,root=ROOT) if natives else None
    installed_native=loader_name((installed/'Core/Brainstorm.lua').read_text(encoding='utf-8'))
    native=evidence['native_file'] if evidence else installed_native
    if evidence and (installed/native).exists() and sha256(installed/native)!=evidence['manifest']['dll']['sha256']:
        raise ValueError('Refusing to replace an existing loaded native artifact; use the content-addressed sidecar')
    fixed=['Core/challenge_opening.lua','UI/advisor.lua','UI/challenge_opening.lua','UI/ui.lua',
           'steamodded_compat.lua',installed_native,'Core/Brainstorm.lua']
    # Keep auxiliary Core/UI modules from the installed baseline in later slices.
    # Unselected worktree modules must never enter the deployment implicitly.
    fixed += [str(f.relative_to(installed)).replace('\\','/') for folder in ('Core','UI') for f in sorted((installed/folder).glob('*.lua'))
              if str(f.relative_to(installed)).replace('\\','/') not in fixed]
    with tempfile.TemporaryDirectory(prefix='advisor-tested-slice-') as temp:
        stage=Path(temp)/'Brainstorm'
        selected=[str(f.relative_to(installed)) for f in sorted((installed/'Advisor').glob('*.lua'))]+fixed
        for rel in selected:
            dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(installed/rel,dest)
        for rel in files:
            source=(ROOT/'Brainstorm'/rel).resolve()
            source.relative_to((ROOT/'Brainstorm').resolve())
            dest=stage/source.relative_to(ROOT/'Brainstorm');dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,dest)
        if loader_name((stage/'Core/Brainstorm.lua').read_text(encoding='utf-8'))!=native:
            raise ValueError('Staged loader changes the native artifact without matching tested evidence')
        if evidence:
            if sha256(stage/native)!=evidence['manifest']['dll']['sha256']: raise ValueError('DLL changed while staging')
            for rel in files:
                if rel.endswith('.lua') and sha256(stage/rel)!=evidence['manifest']['runtime_files']['Brainstorm/'+rel]:
                    raise ValueError('Tested Lua companion changed while staging')
        for rel in VERSION_FIELDS:
            for file in [stage/rel,ROOT/'Brainstorm'/rel]:
                stamp_version(file,rel,a.version)
        result=subprocess.run(['pwsh','-NoProfile','-File',str(ROOT/'tools/install_advisor.ps1'),
                               '-Source',str(stage),'-NativeFile',native],capture_output=True,text=True,
                              creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        if result.returncode:
            raise RuntimeError(result.stdout+'\n'+result.stderr)
        report=json.loads(result.stdout.lstrip('\ufeff'))
        if evidence:
            receipt=Path(report['backup'])/'native-evidence.json'
            receipt.write_bytes(evidence['manifest_bytes'])
            if sha256(receipt)!=evidence['manifest_sha256']: raise ValueError('Native evidence changed during installation')
            report['nativeEvidence']={'path':str(receipt),'sha256':evidence['manifest_sha256'],
                'dllSHA256':evidence['manifest']['dll']['sha256']}
            (Path(report['backup'])/'deployment.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({key:report[key] for key in ['version','installedAt','backup','configSHA256','activation']}))
        print('Verified runtime files:',len(report['files']))

if __name__=='__main__': main()
