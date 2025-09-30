# -*- coding: utf-8 -*-

"""
universal_decryptor.py

A Python implementation of the core decryption logic from the unlock-music project.
This script consolidates various decryption algorithms for different music file formats.

Dependencies:
- pycryptodome: `pip install pycryptodome`
"""

import base64
import binascii
import io
import math
import os
import struct
import hashlib
from abc import ABC, abstractmethod

try:
    from Crypto.Cipher import AES
except ImportError:
    raise ImportError("PyCryptodome is required. Please install it using: pip install pycryptodome")

# ---[ 1. Generic Interfaces & Factory ]--------------------------------------

DECODER_REGISTRY = {}

class StreamDecoder(ABC):
    """Abstract base class for stream ciphers."""
    @abstractmethod
    def decrypt(self, buffer: bytearray, offset: int):
        raise NotImplementedError

class FileDecoder(ABC):
    """Abstract base class for file format decoders."""
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.file_handle = open(file_path, 'rb')
        self.audio_stream = None
        self.output_ext = ".bin"

    @abstractmethod
    def validate(self) -> bool:
        """Validate the file format and prepare for decryption."""
        raise NotImplementedError

    def get_audio_stream(self) -> io.BytesIO:
        """Get the decrypted audio stream."""
        if not self.audio_stream:
            self.file_handle.seek(0)
            # This is a placeholder; subclasses should implement proper stream handling
            self.audio_stream = io.BytesIO(self.file_handle.read())
        return self.audio_stream

    def get_output_ext(self) -> str:
        return self.output_ext

    def read(self, size=-1):
        return self.audio_stream.read(size)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.file_handle:
            self.file_handle.close()

def register_decoder(extension: str, decoder_class):
    """Register a decoder class for a given file extension."""
    ext = "." + extension.lstrip(".")
    if ext not in DECODER_REGISTRY:
        DECODER_REGISTRY[ext] = []
    DECODER_REGISTRY[ext].append(decoder_class)

def get_decoder(file_path: str):
    """Get the first valid decoder for a given file path."""
    filename = os.path.basename(file_path).lower()
    for ext, decoders in sorted(DECODER_REGISTRY.items(), key=lambda x: len(x[0]), reverse=True):
        if filename.endswith(ext):
            for decoder_cls in decoders:
                try:
                    decoder_instance = decoder_cls(file_path)
                    if decoder_instance.validate():
                        return decoder_instance
                except Exception:
                    if 'decoder_instance' in locals() and decoder_instance.file_handle:
                        decoder_instance.file_handle.close()
                    continue
    return None

# ---[ 2. Cryptography Utilities ]--------------------------------------------

def pkcs7_unpad(data: bytes) -> bytes:
    pad_len = data[-1]
    if pad_len > len(data):
        return data
    return data[:-pad_len]

def decrypt_aes_128_ecb(data: bytes, key: bytes) -> bytes:
    cipher = AES.new(key, AES.MODE_ECB)
    return cipher.decrypt(data)

def _tea_decrypt_block(v, k):
    v0, v1 = struct.unpack('>2I', v)
    k0, k1, k2, k3 = struct.unpack('>4I', k)
    delta = 0x9e3779b9
    s = (delta * 32) & 0xFFFFFFFF
    for _ in range(32):
        v1 = (v1 - (((v0 << 4) + k2) ^ (v0 + s) ^ ((v0 >> 5) + k3))) & 0xFFFFFFFF
        v0 = (v0 - (((v1 << 4) + k0) ^ (v1 + s) ^ ((v1 >> 5) + k1))) & 0xFFFFFFFF
        s = (s - delta) & 0xFFFFFFFF
    return struct.pack('>2I', v0, v1)

def decrypt_tencent_tea(data: bytes, key: bytes) -> bytes:
    if len(data) % 8 != 0 or len(data) < 16:
        raise ValueError("Invalid data length for TEA decryption")
    
    decrypted_first_block = _tea_decrypt_block(data[:8], key)
    pad_len = decrypted_first_block[0] & 0x07
    out_len = len(data) - 1 - pad_len - 2 - 7
    if out_len < 0:
        raise ValueError("Invalid padding or data length")

    out = bytearray(out_len)
    iv_prev = bytearray(8)
    iv_cur = bytearray(data[:8])
    in_buf_pos = 8
    dest_idx = 1 + pad_len
    decrypted_block = bytearray(decrypted_first_block)

    def crypt_block():
        nonlocal in_buf_pos, dest_idx, iv_prev, iv_cur, decrypted_block
        iv_prev[:] = iv_cur
        iv_cur[:] = data[in_buf_pos : in_buf_pos + 8]
        temp_block = bytes(a ^ b for a, b in zip(decrypted_block, iv_cur))
        decrypted_block = bytearray(_tea_decrypt_block(temp_block, key))
        in_buf_pos += 8
        dest_idx = 0

    i = 1
    while i <= 2: # Skip salt
        if dest_idx < 8:
            dest_idx += 1
            i += 1
        elif dest_idx == 8:
            crypt_block()

    out_pos = 0
    while out_pos < out_len:
        if dest_idx < 8:
            out[out_pos] = decrypted_block[dest_idx] ^ iv_prev[dest_idx]
            dest_idx += 1
            out_pos += 1
        elif dest_idx == 8:
            crypt_block()
            
    for i in range(1, 8): # Verify zero padding
        if dest_idx < 8:
            if (decrypted_block[dest_idx] ^ iv_prev[dest_idx]) != 0:
                 raise ValueError("TEA zero-check failed")
            dest_idx += 1
        elif dest_idx == 8:
            crypt_block()
            if (decrypted_block[0] ^ iv_prev[0]) != 0:
                 raise ValueError("TEA zero-check failed")
            dest_idx = 1
    return bytes(out)

# ---[ 3. QMC Key Derivation ]------------------------------------------------

def _qmc_simple_make_key(salt, length):
    key = bytearray(length)
    for i in range(length):
        val = math.tan(float(salt) + float(i) * 0.1)
        key[i] = int(abs(val) * 100.0)
    return bytes(key)

def _derive_qmc_key_v1(raw_key_dec):
    if len(raw_key_dec) < 16:
        raise ValueError("QMC v1 key length is too short")
    simple_key = _qmc_simple_make_key(106, 8)
    tea_key = bytearray(16)
    for i in range(8):
        tea_key[i*2] = simple_key[i]
        tea_key[i*2+1] = raw_key_dec[i]
    rs = decrypt_tencent_tea(raw_key_dec[8:], bytes(tea_key))
    return raw_key_dec[:8] + rs

_QMC_V2_KEY1 = b"\x33\x38\x36\x5A\x4A\x59\x21\x40\x23\x2A\x24\x25\x5E\x26\x29\x28"
_QMC_V2_KEY2 = b"\x2A\x2A\x23\x21\x28\x23\x24\x25\x26\x5E\x61\x31\x63\x5A\x2C\x54"

def _derive_qmc_key_v2(raw):
    buf = decrypt_tencent_tea(raw, _QMC_V2_KEY1)
    buf = decrypt_tencent_tea(buf, _QMC_V2_KEY2)
    return base64.b64decode(buf)

def derive_qmc_key(raw_key):
    try:
        raw_key_dec = base64.b64decode(raw_key)
    except (binascii.Error, ValueError):
        return None
    if raw_key_dec.startswith(b"QQMusic EncV2,Key:"):
        return _derive_qmc_key_v2(raw_key_dec[len(b"QQMusic EncV2,Key:"):])
    else:
        return _derive_qmc_key_v1(raw_key_dec)

# ---[ 4. Stream Cipher Implementations ]-------------------------------------

class NcmCipher(StreamDecoder):
    def __init__(self, key: bytes):
        self.box = self._build_key_box(key)
    def _build_key_box(self, key: bytes) -> bytes:
        box = bytearray(range(256))
        j = 0
        for i in range(256):
            j = (j + box[i] + key[i % len(key)]) & 0xFF
            box[i], box[j] = box[j], box[i]
        ret = bytearray(256)
        for i in range(256):
            _i = (i + 1) & 0xFF
            si = box[_i]
            sj = box[(_i + si) & 0xFF]
            ret[i] = box[(si + sj) & 0xFF]
        return bytes(ret)
    def decrypt(self, buffer: bytearray, offset: int):
        for i in range(len(buffer)):
            buffer[i] ^= self.box[(offset + i) & 0xFF]

class QmcStaticCipher(StreamDecoder):
    _BOX = bytes([
        0x77, 0x48, 0x32, 0x73, 0xDE, 0xF2, 0xC0, 0xC8, 0x95, 0xEC, 0x30, 0xB2, 0x51, 0xC3, 0xE1, 0xA0,
        0x9E, 0xE6, 0x9D, 0xCF, 0xFA, 0x7F, 0x14, 0xD1, 0xCE, 0xB8, 0xDC, 0xC3, 0x4A, 0x67, 0x93, 0xD6,
        0x28, 0xC2, 0x91, 0x70, 0xCA, 0x8D, 0xA2, 0xA4, 0xF0, 0x08, 0x61, 0x90, 0x7E, 0x6F, 0xA2, 0xE0,
        0xEB, 0xAE, 0x3E, 0xB6, 0x67, 0xC7, 0x92, 0xF4, 0x91, 0xB5, 0xF6, 0x6C, 0x5E, 0x84, 0x40, 0xF7,
        0xF3, 0x1B, 0x02, 0x7F, 0xD5, 0xAB, 0x41, 0x89, 0x28, 0xF4, 0x25, 0xCC, 0x52, 0x11, 0xAD, 0x43,
        0x68, 0xA6, 0x41, 0x8B, 0x84, 0xB5, 0xFF, 0x2C, 0x92, 0x4A, 0x26, 0xD8, 0x47, 0x6A, 0x7C, 0x95,
        0x61, 0xCC, 0xE6, 0xCB, 0xBB, 0x3F, 0x47, 0x58, 0x89, 0x75, 0xC3, 0x75, 0xA1, 0xD9, 0xAF, 0xCC,
        0x08, 0x73, 0x17, 0xDC, 0xAA, 0x9A, 0xA2, 0x16, 0x41, 0xD8, 0xA2, 0x06, 0xC6, 0x8B, 0xFC, 0x66,
        0x34, 0x9F, 0xCF, 0x18, 0x23, 0xA0, 0x0A, 0x74, 0xE7, 0x2B, 0x27, 0x70, 0x92, 0xE9, 0xAF, 0x37,
        0xE6, 0x8C, 0xA7, 0xBC, 0x62, 0x65, 0x9C, 0xC2, 0x08, 0xC9, 0x88, 0xB3, 0xF3, 0x43, 0xAC, 0x74,
        0x2C, 0x0F, 0xD4, 0xAF, 0xA1, 0xC3, 0x01, 0x64, 0x95, 0x4E, 0x48, 0x9F, 0xF4, 0x35, 0x78, 0x95,
        0x7A, 0x39, 0xD6, 0x6A, 0xA0, 0x6D, 0x40, 0xE8, 0x4F, 0xA8, 0xEF, 0x11, 0x1D, 0xF3, 0x1B, 0x3F,
        0x3F, 0x07, 0xDD, 0x6F, 0x5B, 0x19, 0x30, 0x19, 0xFB, 0xEF, 0x0E, 0x37, 0xF0, 0x0E, 0xCD, 0x16,
        0x49, 0xFE, 0x53, 0x47, 0x13, 0x1A, 0xBD, 0xA4, 0xF1, 0x40, 0x19, 0x60, 0x0E, 0xED, 0x68, 0x09,
        0x06, 0x5F, 0x4D, 0xCF, 0x3D, 0x1A, 0xFE, 0x20, 0x77, 0xE4, 0xD9, 0xDA, 0xF9, 0xA4, 0x2B, 0x76,
        0x1C, 0x71, 0xDB, 0x00, 0xBC, 0xFD, 0x0C, 0x6C, 0xA5, 0x47, 0xF7, 0xF6, 0x00, 0x79, 0x4A, 0x11,
    ])
    def _get_mask(self, offset: int) -> int:
        if offset > 0x7FFF: offset %= 0x7FFF
        return self._BOX[(offset * offset + 27) & 0xFF]
    def decrypt(self, buffer: bytearray, offset: int):
        for i in range(len(buffer)):
            buffer[i] ^= self._get_mask(offset + i)

class QmcMapCipher(StreamDecoder):
    def __init__(self, key: bytes):
        if not key: raise ValueError("QMC Map Cipher key cannot be empty")
        self.key, self.key_len = key, len(key)
    def _rotate(self, value: int, bits: int) -> int:
        return ((value << (bits + 4) % 8) & 0xFF) | (value >> (8 - (bits + 4) % 8))
    def _get_mask(self, offset: int) -> int:
        if offset > 0x7FFF: offset %= 0x7FFF
        idx = (offset * offset + 71214) % self.key_len
        return self._rotate(self.key[idx], idx & 0x07)
    def decrypt(self, buffer: bytearray, offset: int):
        for i in range(len(buffer)):
            buffer[i] ^= self._get_mask(offset + i)

class QmcRc4Cipher(StreamDecoder):
    def __init__(self, key: bytes):
        self.key, self.n = key, len(key)
        self.box = self._init_box(key)
        self.hash = self._get_hash_base()
    def _init_box(self, key):
        box = bytearray(range(self.n))
        j = 0
        for i in range(self.n):
            j = (j + box[i] + key[i % self.n]) % self.n
            box[i], box[j] = box[j], box[i]
        return box
    def _get_hash_base(self):
        h = 1
        for val in self.key:
            if val == 0: continue
            next_hash = h * val
            if next_hash == 0 or next_hash <= h: break
            h = next_hash
        return h
    def _get_segment_skip(self, seg_id):
        seed = self.key[seg_id % self.n]
        idx = int(self.hash / ((seg_id + 1) * seed) * 100.0)
        return idx % self.n
    def decrypt(self, buffer: bytearray, offset: int):
        # This is a simplified implementation for demonstration.
        # The original is segmented and more complex.
        box = self.box[:]
        j, k = 0, 0
        for i in range(len(buffer)):
            j = (j + 1) % self.n
            k = (k + box[j]) % self.n
            box[j], box[k] = box[k], box[j]
            buffer[i] ^= box[(box[j] + box[k]) % self.n]

class KwmCipher(StreamDecoder):
    _KEY_PRE_DEFINED = b"MoOtOiTvINGwd2E6n0E1i7L5t2IoOoNk"
    def __init__(self, key: bytes):
        self.mask = self._generate_mask(key)
    def _pad_or_truncate(self, s: str, length: int) -> str:
        if len(s) > length: return s[:length]
        if len(s) < length: return (s * (length // len(s) + 1))[:length]
        return s
    def _generate_mask(self, key: bytes) -> bytes:
        key_int = struct.unpack('<Q', key)[0]
        key_str = self._pad_or_truncate(str(key_int), 32)
        return bytes(a ^ b for a, b in zip(self._KEY_PRE_DEFINED, key_str.encode('ascii')))
    def decrypt(self, buffer: bytearray, offset: int):
        for i in range(len(buffer)):
            buffer[i] ^= self.mask[(offset + i) & 0x1F]

class XmCipher(StreamDecoder):
    def __init__(self, mask: int, start_offset: int):
        self.mask, self.start_offset = mask, start_offset
    def decrypt(self, buffer: bytearray, offset: int):
        for i in range(len(buffer)):
            if offset + i >= self.start_offset:
                buffer[i] ^= self.mask

# ---[ 5. File Decoder Implementations ]--------------------------------------

class NcmDecoder(FileDecoder):
    _CORE_KEY = b"\x68\x7a\x48\x52\x41\x6d\x73\x6f\x35\x6b\x49\x6e\x62\x61\x78\x57"
    def validate(self) -> bool:
        try:
            self.file_handle.seek(0)
            if self.file_handle.read(8) != b"CTENFDAM": return False
            
            self.file_handle.seek(2, 1) # Skip 2 bytes
            
            key_len_bytes = self.file_handle.read(4)
            if len(key_len_bytes) < 4: return False
            key_len = struct.unpack('<I', key_len_bytes)[0]
            
            key_data_enc = self.file_handle.read(key_len)
            if len(key_data_enc) < key_len: return False
            key_data_dec = bytes(b ^ 0x64 for b in key_data_enc)
            
            decrypted_key_block = decrypt_aes_128_ecb(key_data_dec, self._CORE_KEY)
            self.stream_key = pkcs7_unpad(decrypted_key_block)[17:]
            
            # --- Find audio data start (Corrected Logic) ---
            # The file handle is currently right after the encrypted key data.
            
            # Read and skip metadata
            meta_len_bytes = self.file_handle.read(4)
            if len(meta_len_bytes) < 4: return False
            meta_len = struct.unpack('<I', meta_len_bytes)[0]
            if meta_len > 0:
                self.file_handle.seek(meta_len, 1)
            
            # Skip gap
            self.file_handle.seek(5, 1)
            
            # Read and skip album art
            self.file_handle.seek(4, 1) # Skip cover frame length
            img_len_bytes = self.file_handle.read(4)
            if len(img_len_bytes) < 4: return False
            img_len = struct.unpack('<I', img_len_bytes)[0]
            if img_len > 0:
                self.file_handle.seek(img_len, 1)
            
            # --- End of seeking logic ---
            
            audio_offset = self.file_handle.tell()
            self.file_handle.seek(0, 2)
            audio_len = self.file_handle.tell() - audio_offset
            
            self.file_handle.seek(audio_offset)
            cipher = NcmCipher(self.stream_key)
            
            encrypted_audio = self.file_handle.read(audio_len)
            decrypted_audio = bytearray(encrypted_audio)
            cipher.decrypt(decrypted_audio, 0)
            self.audio_stream = io.BytesIO(decrypted_audio)
            
            self.output_ext = ".flac" if decrypted_audio.startswith(b"fLaC") else ".mp3"
            return True
        except (struct.error, IndexError):
            # This can happen if the file is not a valid NCM file and reads go past EOF
            return False

class QmcDecoder(FileDecoder):
    def validate(self) -> bool:
        self.file_handle.seek(-4, 2)
        file_size = self.file_handle.tell() + 4
        key_len_bytes = self.file_handle.read(4)
        
        key_len = struct.unpack('<I', key_len_bytes)[0]
        if key_len > 0 and key_len < 0xFFFF:
            self.file_handle.seek(-(4 + key_len), 2)
            raw_key = self.file_handle.read(key_len)
            self.audio_len = file_size - 4 - key_len
        else: # Static cipher
            self.audio_len = file_size
            raw_key = b""

        if raw_key:
            self.decoded_key = derive_qmc_key(raw_key)
            if not self.decoded_key: return False
        else:
            self.decoded_key = b""

        if len(self.decoded_key) > 300:
            self.cipher = QmcRc4Cipher(self.decoded_key)
        elif len(self.decoded_key) > 0:
            self.cipher = QmcMapCipher(self.decoded_key)
        else:
            self.cipher = QmcStaticCipher()

        # Decrypt and set up stream
        self.file_handle.seek(0)
        encrypted_audio = self.file_handle.read(self.audio_len)
        decrypted_audio = bytearray(encrypted_audio)
        self.cipher.decrypt(decrypted_audio, 0)
        self.audio_stream = io.BytesIO(decrypted_audio)
        
        # Sniff extension
        if decrypted_audio.startswith(b"fLaC"): self.output_ext = ".flac"
        elif decrypted_audio.startswith(b"OggS"): self.output_ext = ".ogg"
        else: self.output_ext = ".mp3"
        return True

class KwmDecoder(FileDecoder):
    def validate(self) -> bool:
        self.file_handle.seek(0)
        header = self.file_handle.read(0x400)
        if not (header.startswith(b"yeelion-kuwo-tme") or header.startswith(b"yeelion-kuwo\x00\x00\x00\x00")):
            return False
        
        key = header[0x18:0x20]
        cipher = KwmCipher(key)
        
        bitrate_info = header[0x30:0x38].strip(b'\x00').decode('ascii', 'ignore')
        self.output_ext = "".join(filter(str.isalpha, bitrate_info)).lower()
        if not self.output_ext: self.output_ext = "mp3"

        self.file_handle.seek(0x400)
        encrypted_audio = self.file_handle.read()
        decrypted_audio = bytearray(encrypted_audio)
        cipher.decrypt(decrypted_audio, 0)
        self.audio_stream = io.BytesIO(decrypted_audio)
        return True

class XiamiDecoder(FileDecoder):
    def validate(self) -> bool:
        self.file_handle.seek(0)
        header = self.file_handle.read(16)
        if not (header.startswith(b"ifmt") and header[8:12] == b"\xfe\xfe\xfe\xfe"):
            return False
        
        start_offset = struct.unpack('<I', header[12:16])[0] & 0xFFFFFF
        mask = header[15]
        cipher = XmCipher(mask, start_offset)
        
        self.file_handle.seek(16)
        encrypted_audio = self.file_handle.read()
        decrypted_audio = bytearray(encrypted_audio)
        cipher.decrypt(decrypted_audio, 0)
        self.audio_stream = io.BytesIO(decrypted_audio)
        
        self.output_ext = ".wav" if decrypted_audio.startswith(b"RIFF") else ".mp3"
        return True

# ---[ 6. Registration ]------------------------------------------------------

register_decoder("ncm", NcmDecoder)
for ext in ["qmc0", "qmc3", "qmcflac", "qmcogg", "mflac", "mgg", "mflac0"]:
    register_decoder(ext, QmcDecoder)
register_decoder("kwm", KwmDecoder)
register_decoder("xm", XiamiDecoder)

# ---[ 7. Main Execution ]----------------------------------------------------

def process_file(input_path):
    """Processes a single encrypted file."""
    print(f"--> Processing file: {input_path}")
    decoder = get_decoder(input_path)

    if not decoder:
        print(f"    [SKIP] No suitable decoder found for '{os.path.basename(input_path)}'.")
        return

    try:
        output_ext = decoder.get_output_ext()
        output_path = os.path.splitext(input_path)[0] + output_ext
        
        print(f"    [OK] Decoder '{decoder.__class__.__name__}' found. Writing to '{os.path.basename(output_path)}'")

        with open(output_path, 'wb') as f_out:
            f_out.write(decoder.get_audio_stream().read())
        
    except Exception as e:
        print(f"    [FAIL] An error occurred during decryption: {e}")
    finally:
        if decoder:
            decoder.__exit__(None, None, None)

def process_directory(input_dir):
    """Recursively finds and processes all files in a directory."""
    print(f"Scanning directory: {input_dir}")
    for root, _, files in os.walk(input_dir):
        for file in files:
            file_path = os.path.join(root, file)
            process_file(file_path)

def main():
    import sys
    if len(sys.argv) != 2:
        print(f"Usage: python {sys.argv[0]} <encrypted_file_or_folder_path>")
        return

    input_path = sys.argv[1]
    if not os.path.exists(input_path):
        print(f"Error: Path not found at '{input_path}'")
        return

    if os.path.isdir(input_path):
        process_directory(input_path)
    elif os.path.isfile(input_path):
        process_file(input_path)
    else:
        print(f"Error: Input path is not a valid file or directory.")
    
    print("\nProcessing complete.")

if __name__ == '__main__':
    main()