# lib.sh — shared shell helpers for the install scripts in this repo
# Source this file; it defines functions only and has no side effects.

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
