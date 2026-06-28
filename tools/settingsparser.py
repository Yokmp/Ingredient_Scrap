"""
Read and update the Factorio mod-settings.dat startup settings file.

Examples:
    python tools/settingsparser.py --mod MODNAME --setting SETTING
    python tools/settingsparser.py --mod MODNAME --setting SETTING --value true

The CLI defaults to the mod-settings.dat next to this mod folder. Factorio stores
startup settings by setting name inside the file; --mod is kept as a required
label so commands stay explicit when shared with other mod authors.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any


DEFAULT_HEADER = bytes([2, 0, 0, 0, 77, 0, 0, 0, 0])
DEFAULT_SETTINGS_FILE = Path(__file__).resolve().parents[2] / "mod-settings.dat"


class PropertyTreeReader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def read_u8(self) -> int:
        value = self.data[self.offset]
        self.offset += 1
        return value

    def read_u32(self) -> int:
        value = struct.unpack_from("<I", self.data, self.offset)[0]
        self.offset += 4
        return value

    def read_f64(self) -> float:
        value = struct.unpack_from("<d", self.data, self.offset)[0]
        self.offset += 8
        return value

    def read_s64(self) -> int:
        value = struct.unpack_from("<q", self.data, self.offset)[0]
        self.offset += 8
        return value

    def read_string(self) -> str:
        is_nil = self.read_u8()
        if is_nil:
            return ""
        length = self.read_u8()
        if length == 255:
            length = self.read_u32()
        value = self.data[self.offset:self.offset + length].decode("utf-8")
        self.offset += length
        return value

    def read_node(self) -> Any:
        node_type = self.read_u8()
        if node_type == 0:
            return None
        self.read_u8()
        if node_type == 1:
            return self.read_u8() != 0
        if node_type == 2:
            return self.read_f64()
        if node_type == 3:
            return self.read_string()
        if node_type == 4:
            return [self.read_node() for _ in range(self.read_u32())]
        if node_type == 5:
            return {self.read_string(): self.read_node() for _ in range(self.read_u32())}
        if node_type == 6:
            return self.read_s64()
        raise ValueError(f"Unknown property tree node type {node_type} at byte {self.offset - 1}")


class PropertyTreeWriter:
    def __init__(self):
        self.out = bytearray()

    def write_u8(self, value: int) -> None:
        self.out.append(value)

    def write_u32(self, value: int) -> None:
        self.out.extend(struct.pack("<I", value))

    def write_f64(self, value: float) -> None:
        self.out.extend(struct.pack("<d", value))

    def write_s64(self, value: int) -> None:
        self.out.extend(struct.pack("<q", value))

    def write_string(self, value: str) -> None:
        encoded = value.encode("utf-8")
        self.write_u8(0)
        if len(encoded) < 255:
            self.write_u8(len(encoded))
        else:
            self.write_u8(255)
            self.write_u32(len(encoded))
        self.out.extend(encoded)

    def write_node(self, value: Any) -> None:
        if value is None:
            self.write_u8(0)
        elif isinstance(value, bool):
            self.write_u8(1)
            self.write_u8(0)
            self.write_u8(1 if value else 0)
        elif isinstance(value, int):
            self.write_u8(6)
            self.write_u8(0)
            self.write_s64(value)
        elif isinstance(value, float):
            self.write_u8(2)
            self.write_u8(0)
            self.write_f64(float(value))
        elif isinstance(value, str):
            self.write_u8(3)
            self.write_u8(0)
            self.write_string(value)
        elif isinstance(value, list):
            self.write_u8(4)
            self.write_u8(0)
            self.write_u32(len(value))
            for item in value:
                self.write_node(item)
        elif isinstance(value, dict):
            self.write_u8(5)
            self.write_u8(0)
            self.write_u32(len(value))
            for key, item in value.items():
                self.write_string(str(key))
                self.write_node(item)
        else:
            raise TypeError(f"Unsupported property tree value: {value!r}")


def read_mod_settings_bytes(data: bytes) -> tuple[bytes, dict[str, Any]]:
    header = data[:9]
    reader = PropertyTreeReader(data[9:])
    root = reader.read_node()
    if not isinstance(root, dict):
        raise ValueError("mod-settings.dat root is not a dictionary")
    return header, root


def write_mod_settings_bytes(header: bytes, root: dict[str, Any]) -> bytes:
    writer = PropertyTreeWriter()
    writer.write_node(root)
    return header + bytes(writer.out)


def read_mod_settings(path: Path) -> tuple[bytes, dict[str, Any]]:
    if not path.exists():
        return DEFAULT_HEADER, {}
    return read_mod_settings_bytes(path.read_bytes())


def write_mod_settings(path: Path, header: bytes, root: dict[str, Any]) -> None:
    path.write_bytes(write_mod_settings_bytes(header, root))


def parse_value(value: str) -> Any:
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered == "nil":
        return None
    try:
        if "." not in value:
            return int(value)
        return float(value)
    except ValueError:
        return value


def set_startup_setting(path: Path, setting: str, value: Any) -> None:
    header, root = read_mod_settings(path)
    startup = root.setdefault("startup", {})
    if not isinstance(startup, dict):
        raise ValueError("mod-settings.dat startup section is not a dictionary")
    startup[setting] = {"value": value}
    write_mod_settings(path, header, root)


def get_startup_setting(path: Path, setting: str) -> Any:
    _, root = read_mod_settings(path)
    startup = root.get("startup", {})
    if not isinstance(startup, dict):
        return None
    entry = startup.get(setting)
    if isinstance(entry, dict):
        return entry.get("value")
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Read or update the local Factorio mod-settings.dat startup setting.",
        epilog=(
            f"Default settings file: {DEFAULT_SETTINGS_FILE}\n"
            "Values are parsed as true, false, nil, integers, floats, or strings. "
            "Factorio stores startup settings by setting name; --mod is required "
            "for command clarity but is not a separate namespace in mod-settings.dat."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--mod", required=True, metavar="MODNAME", help="Mod name label, for example Ingredient_Scrap")
    parser.add_argument("--setting", required=True, metavar="SETTING", help="Startup setting name")
    parser.add_argument("--value", metavar="VALUE", help="Value to write. Omit to print the current value.")
    parser.add_argument("--file", type=Path, default=DEFAULT_SETTINGS_FILE, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.value is None:
        print(json.dumps(get_startup_setting(args.file, args.setting), ensure_ascii=False))
    else:
        value = parse_value(args.value)
        set_startup_setting(args.file, args.setting, value)
        print(f"{args.setting} = {json.dumps(value, ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
