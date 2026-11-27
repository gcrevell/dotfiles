#!/usr/bin/env python3
"""PreToolUse hook for Bash: refuse a recursive rm whose arguments use a shell variable or command substitution."""
import json
import re
import sys

COMMAND_START = re.compile(
    r'^\s*(?:[({!]\s*|(?:then|do|else|time|nohup|nice|sudo|command|builtin|exec|env)\s+|\w+=\S*\s+|xargs(?:\s+-\S+)*\s+)*'
    r'(?:\S*/)?rm\s+(?P<args>.*)$'
)


def segments(command):
    for line in command.replace('\\\n', ' ').splitlines():
        yield from re.split(r'&&|\|\||[;|&]', line)


def recursive(args):
    for word in args.split():
        if word == '--':
            return False
        if word == '--recursive' or re.fullmatch(r'-[a-zA-Z]*[rR][a-zA-Z]*', word):
            return True
    return False


def offending(command):
    for segment in segments(command):
        match = COMMAND_START.match(segment)
        if match and recursive(match['args']) and re.search(r'[$`]', match['args']):
            return segment.strip()
    return None


try:
    command = json.load(sys.stdin)['tool_input']['command']
except (ValueError, KeyError, TypeError):
    sys.exit(0)

found = offending(command)
if found:
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'deny',
            'permissionDecisionReason': (
                f'Blocked `{found}`: rm -r/-rf on a path from a shell variable or $(...) is not allowed. '
                'Write the full literal path in the rm command instead.'
            ),
        }
    }))
