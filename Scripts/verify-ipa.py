"""Validate a real-device, unsigned iOS IPA without requiring macOS."""
import json
import pathlib
import plistlib
import stat
import struct
import sys
import zipfile

ARM64 = 0x0100000C
MACHO64 = 0xFEEDFACF
LC_CODE_SIGNATURE = 0x1D
LC_BUILD_VERSION = 0x32


def macho_info(data):
    if len(data) < 32:
        raise ValueError('Truncated Mach-O header')
    magic, cpu, subtype, filetype, commands, size, flags, reserved = struct.unpack_from('<8I', data)
    if magic != MACHO64 or cpu != ARM64:
        raise ValueError('Expected a thin arm64 Mach-O for a physical iPhone')
    offset = 32
    platform = None
    for _ in range(commands):
        if offset + 8 > len(data):
            raise ValueError('Truncated Mach-O load command')
        command, length = struct.unpack_from('<II', data, offset)
        if length < 8 or offset + length > len(data):
            raise ValueError('Invalid Mach-O load-command size')
        if command == LC_CODE_SIGNATURE:
            if length < 16:
                raise ValueError('Truncated code-signature command')
            _, signature_size = struct.unpack_from('<II', data, offset + 8)
            if signature_size:
                raise ValueError('IPA still contains a code signature')
        if command == LC_BUILD_VERSION:
            if length < 24:
                raise ValueError('Truncated build-version command')
            platform = struct.unpack_from('<I', data, offset + 8)[0]
        offset += length
    if platform != 2:
        raise ValueError('Expected iOS device platform; simulator binaries are not installable')
    return {'architecture': 'arm64', 'platform': 'iOS', 'unsigned': True}


def validate(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate ZIP members')
        for name in names:
            parts = pathlib.PurePosixPath(name).parts
            if not parts or parts[0] != 'Payload' or '..' in parts or name.startswith('/'):
                raise ValueError('Unsafe IPA member: ' + name)
            if '_CodeSignature' in parts or parts[-1] == 'embedded.mobileprovision':
                raise ValueError('Signing metadata found in IPA')
        apps = [name for name in names if name.count('/') == 2 and name.endswith('.app/Info.plist')]
        if len(apps) != 1:
            raise ValueError('IPA must contain exactly one main app')
        main_path = apps[0].rsplit('/', 1)[0]
        main = plistlib.loads(archive.read(apps[0]))
        main_id = main['CFBundleIdentifier']
        if main.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
            raise ValueError('Main app is not an iPhoneOS build')
        bundles = [name for name in names if name.endswith('/Info.plist')
                   and (name.rsplit('/', 1)[0].endswith('.app')
                        or name.rsplit('/', 1)[0].endswith('.appex'))]
        inspected = []
        for plist_path in bundles:
            bundle = plistlib.loads(archive.read(plist_path))
            prefix = plist_path.rsplit('/', 1)[0]
            bundle_id = bundle['CFBundleIdentifier']
            if prefix != main_path and not bundle_id.startswith(main_id + '.'):
                raise ValueError('Extension Bundle ID is not prefixed by the main app ID')
            executable = prefix + '/' + bundle['CFBundleExecutable']
            mode = archive.getinfo(executable).external_attr >> 16
            if not mode & stat.S_IXUSR:
                raise ValueError('Executable permission missing: ' + executable)
            inspected.append({'bundle_id': bundle_id, **macho_info(archive.read(executable))})
        # Check embedded frameworks and dynamic libraries as well as app executables.
        for member in archive.infolist():
            if member.is_dir() or member.file_size < 4:
                continue
            with archive.open(member) as stream:
                magic = stream.read(4)
            if magic == struct.pack('<I', MACHO64):
                macho_info(archive.read(member))
        return {'app': main_id, 'version': main['CFBundleShortVersionString'],
                'minimum_ios': main['MinimumOSVersion'], 'bundles': inspected}


if __name__ == '__main__':
    try:
        print(json.dumps(validate(sys.argv[1]), ensure_ascii=False, indent=2))
    except (ValueError, KeyError, zipfile.BadZipFile, OSError, plistlib.InvalidFileException) as error:
        raise SystemExit('IPA validation failed: ' + str(error)) from error
