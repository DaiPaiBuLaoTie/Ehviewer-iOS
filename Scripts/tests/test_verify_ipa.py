import importlib.util
import pathlib
import plistlib
import struct
import tempfile
import unittest
import zipfile

MODULE = pathlib.Path(__file__).resolve().parents[1] / 'verify-ipa.py'
spec = importlib.util.spec_from_file_location('verify_ipa', MODULE)
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


def binary(platform=2, signed=False):
    commands = struct.pack('<6I', 0x32, 24, platform, 0x1A0000, 0x1A0500, 0)
    if signed:
        commands += struct.pack('<4I', 0x1D, 16, 80, 32)
    return struct.pack('<8I', 0xFEEDFACF, 0x100000C, 0, 2, 2 if signed else 1, len(commands), 0, 0) + commands


class IPAValidationTests(unittest.TestCase):
    def make_ipa(self, entries=None, platform=2, signed=False, extension_id=None, executable_mode=0o100755):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        output = pathlib.Path(temporary.name) / 'test.ipa'
        main = 'Payload/Test.app/'
        info = {
            'CFBundleIdentifier': 'org.example.test', 'CFBundleExecutable': 'Test',
            'CFBundleShortVersionString': '0.1', 'MinimumOSVersion': '26.0',
            'CFBundleSupportedPlatforms': ['iPhoneOS']
        }
        records = {main + 'Info.plist': plistlib.dumps(info), main + 'Test': binary(platform, signed)}
        if extension_id:
            extension = main + 'PlugIns/Share.appex/'
            records[extension + 'Info.plist'] = plistlib.dumps({**info, 'CFBundleIdentifier': extension_id})
            records[extension + 'Test'] = binary()
        records.update(entries or {})
        with zipfile.ZipFile(output, 'w') as archive:
            for name, data in records.items():
                member = zipfile.ZipInfo(name)
                member.create_system = 3
                member.external_attr = (executable_mode if name.endswith('/Test') else 0o100644) << 16
                archive.writestr(member, data)
        return output

    def test_accepts_unsigned_arm64_device_bundle(self):
        result = verify.validate(self.make_ipa(extension_id='org.example.test.share'))
        self.assertEqual(result['app'], 'org.example.test')
        self.assertEqual(len(result['bundles']), 2)

    def test_rejects_simulator(self):
        with self.assertRaisesRegex(ValueError, 'device platform'):
            verify.validate(self.make_ipa(platform=7))

    def test_rejects_code_signature(self):
        with self.assertRaisesRegex(ValueError, 'code signature'):
            verify.validate(self.make_ipa(signed=True))

    def test_rejects_embedded_profile(self):
        with self.assertRaisesRegex(ValueError, 'Signing metadata'):
            verify.validate(self.make_ipa({'Payload/Test.app/embedded.mobileprovision': b'profile'}))

    def test_rejects_signature_directory(self):
        with self.assertRaisesRegex(ValueError, 'Signing metadata'):
            verify.validate(self.make_ipa({'Payload/Test.app/_CodeSignature/CodeResources': b'signature'}))

    def test_rejects_extension_id_mismatch(self):
        with self.assertRaisesRegex(ValueError, 'Extension Bundle ID'):
            verify.validate(self.make_ipa(extension_id='org.other.share'))

    def test_rejects_non_executable_app(self):
        with self.assertRaisesRegex(ValueError, 'permission'):
            verify.validate(self.make_ipa(executable_mode=0o100644))

    def test_rejects_zip_path_traversal(self):
        with self.assertRaisesRegex(ValueError, 'Unsafe IPA member'):
            verify.validate(self.make_ipa({'Payload/../../outside': b'bad'}))

    def test_rejects_x86_binary(self):
        with self.assertRaisesRegex(ValueError, 'arm64'):
            verify.macho_info(struct.pack('<8I', 0xFEEDFACF, 0x1000007, 0, 2, 0, 0, 0, 0))

    def test_rejects_corrupt_load_command(self):
        with self.assertRaisesRegex(ValueError, 'load-command'):
            verify.macho_info(struct.pack('<8I', 0xFEEDFACF, 0x100000C, 0, 2, 1, 8, 0, 0)
                              + struct.pack('<2I', 0x32, 4))

    def test_rejects_signed_embedded_library(self):
        with self.assertRaisesRegex(ValueError, 'code signature'):
            verify.validate(self.make_ipa({'Payload/Test.app/Frameworks/Bad.dylib': binary(signed=True)}))


if __name__ == '__main__':
    unittest.main()
