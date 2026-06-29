#!/usr/bin/env python3

import argparse
import ast
import re
import subprocess
import sys
from pathlib import Path


RULE_NAME = "com_wheel_vo_for_the_emperor"
PREFERENCE_KEYWORDS = [
    "the emperor",
    "emperor",
    "cadia",
    "master",
    "beloved",
    "conclave",
    "omnissiah",
    "machine god",
]


def parse_args():
    parser = argparse.ArgumentParser(description="Generate MustSayForTheEmperor dialogue data.")
    parser.add_argument("strings_dir", type=Path, help="Directory containing Darktide .strings files.")
    parser.add_argument("code_dir", type=Path, help="Directory containing decompiled Darktide Lua files.")
    parser.add_argument(
        "--output",
        type=Path,
        help="Output Lua file. Defaults to the mod dialogue_data.lua file.",
    )

    return parser.parse_args()


def parse_strings_file(file_path):
    strings_data = {}
    current_hash = None

    with file_path.open("r", encoding="utf-8") as file:
        for line in file:
            line = line.strip()

            if " = {" in line:
                equals_pos = line.find(" = {")
                hash_candidate = line[:equals_pos].strip()

                if len(hash_candidate) == 8 and all(char in "0123456789ABCDEF" for char in hash_candidate):
                    current_hash = hash_candidate
                    strings_data[current_hash] = {}
                    continue

            if current_hash and line.startswith("lang_") and " = " in line:
                equals_pos = line.find(" = ")
                lang_part = line[:equals_pos].strip()
                text_part = line[equals_pos + 3:]
                lang_code = int(lang_part[5:])

                if text_part.startswith('"') and text_part.endswith('"'):
                    try:
                        text_part = ast.literal_eval(text_part)
                    except (SyntaxError, ValueError):
                        text_part = text_part[1:-1]

                strings_data[current_hash][lang_code] = text_part

    return strings_data


def load_strings(strings_dir):
    strings_data = {}
    string_files = sorted(strings_dir.glob("*.strings"))

    if not string_files:
        raise FileNotFoundError(f"No .strings files found in {strings_dir}")

    for strings_file in string_files:
        for hash_id, translations in parse_strings_file(strings_file).items():
            strings_data.setdefault(hash_id, {}).update(translations)

    return strings_data


def murmur_hash(text):
    try:
        result = subprocess.run(
            ["dtmt", "murmur", "hash", text],
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        raise RuntimeError("dtmt was not found in PATH") from None
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"dtmt murmur hash failed for {text}: {error}") from error

    return result.stdout.strip()[:8].upper()


def extract_rule_body(lua_source):
    start_match = re.search(rf"\n\t{RULE_NAME} = \{{", lua_source)

    if not start_match:
        return None

    start_index = start_match.end()
    end_match = re.search(r"\n\t\},", lua_source[start_index:])

    if not end_match:
        raise ValueError(f"Unable to find end of {RULE_NAME} rule")

    return lua_source[start_index:start_index + end_match.start()]


def extract_lua_table_body(rule_body, table_name):
    table_match = re.search(rf"\n\t\t{table_name} = \{{(?P<body>.*?)\n\t\t\}},", rule_body, re.S)

    if not table_match:
        raise ValueError(f"Unable to find {table_name} table in {RULE_NAME}")

    return table_match.group("body")


def extract_sound_events(rule_body):
    events_body = extract_lua_table_body(rule_body, "sound_events")

    return re.findall(r'"([^"]+)"', events_body)


def extract_durations(rule_body):
    durations_body = extract_lua_table_body(rule_body, "sound_events_duration")

    return [float(value) for value in re.findall(r"\b\d+(?:\.\d+)?\b", durations_body)]


def is_for_sentence(text):
    normalized = text.strip().lstrip('"“”').lower()

    return normalized.startswith("for ")


def select_preferred_lines(lines):
    for keyword in PREFERENCE_KEYWORDS:
        selected = [line for line in lines if keyword in line["text"].lower()]

        if selected:
            return selected

    return lines


def load_personality_lines(dialogues_dir, strings_data):
    personality_data = {}

    for source_file in sorted(dialogues_dir.glob("on_demand_vo_*.lua")):
        personality = source_file.stem.removeprefix("on_demand_vo_")
        rule_body = extract_rule_body(source_file.read_text(encoding="utf-8"))

        if rule_body is None:
            continue

        sound_events = extract_sound_events(rule_body)
        durations = extract_durations(rule_body)

        if len(sound_events) != len(durations):
            raise ValueError(f"Mismatched sound event and duration count in {source_file.name}")

        lines = []

        for sound_event, duration in zip(sound_events, durations):
            hash_id = murmur_hash(sound_event)
            text = strings_data.get(hash_id, {}).get(0)

            if text is None:
                raise ValueError(f"Missing English localization for {sound_event} ({hash_id})")

            if not is_for_sentence(text):
                continue

            lines.append({
                "sound_event": sound_event,
                "duration": duration,
                "text": text,
            })

        if lines:
            personality_data[personality] = {
                "all": lines,
                "prefer_fte": select_preferred_lines(lines),
            }

    return personality_data


def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_number(value):
    return f"{value:.6f}".rstrip("0").rstrip(".")


def write_rule(file, name, lines, indent):
    inner = indent + "\t"

    file.write(f"{indent}{name} = {{\n")
    file.write(f"{inner}randomize_indexes_n = 0,\n")
    file.write(f"{inner}sound_events_n = {len(lines)},\n")
    file.write(f"{inner}sound_events = {{\n")

    for line in lines:
        file.write(f"{inner}\t{lua_string(line['sound_event'])},\n")

    file.write(f"{inner}}},\n")
    file.write(f"{inner}sound_events_duration = {{\n")

    for line in lines:
        file.write(f"{inner}\t{lua_number(line['duration'])},\n")

    file.write(f"{inner}}},\n")
    file.write(f"{inner}texts = {{\n")

    for line in lines:
        file.write(f"{inner}\t{lua_string(line['text'])},\n")

    file.write(f"{inner}}},\n")
    file.write(f"{inner}randomize_indexes = {{}},\n")
    file.write(f"{indent}}},\n")


def write_lua(output, personality_data):
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", encoding="utf-8", newline="\n") as file:
        file.write("-- Generated by dev/generate_dialogue_data.py. Do not edit manually.\n\n")
        file.write("return {\n")

        for personality in sorted(personality_data):
            data = personality_data[personality]

            file.write(f"\t{personality} = {{\n")
            write_rule(file, "all", data["all"], "\t\t")
            write_rule(file, "prefer_fte", data["prefer_fte"], "\t\t")
            file.write("\t},\n")

        file.write("}\n")


def main():
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    mod_dir = script_dir.parent
    strings_dir = args.strings_dir.resolve()
    code_dir = args.code_dir.resolve()
    dialogues_dir = code_dir / "dialogues" / "generated"
    output = (args.output or mod_dir / "scripts" / "mods" / "MustSayForTheEmperor" / "dialogue_data.lua").resolve()

    if not strings_dir.is_dir():
        raise FileNotFoundError(f"strings_dir does not exist: {strings_dir}")

    if not code_dir.is_dir():
        raise FileNotFoundError(f"code_dir does not exist: {code_dir}")

    if not dialogues_dir.is_dir():
        raise FileNotFoundError(f"dialogues directory does not exist: {dialogues_dir}")

    strings_data = load_strings(strings_dir)
    personality_data = load_personality_lines(dialogues_dir, strings_data)

    if not personality_data:
        raise RuntimeError(f"No {RULE_NAME} dialogue data was generated")

    write_lua(output, personality_data)
    print(f"Generated {len(personality_data)} personalities: {output}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
