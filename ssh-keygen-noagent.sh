#!/bin/sh
#
# git's gpg.ssh.program under --env personal. Installed to
# ~/.local/bin/ssh-keygen-noagent by install.sh.
#
# The signing half of the problem IdentityAgent none solves for connections.
# `ssh-keygen -Y sign` hands the operation to $SSH_AUTH_SOCK whenever one is
# set -- not only for a key the agent holds, but for any key, so pointing
# user.signingkey at a file on disk is not enough on its own. With 1Password
# answering that socket, every commit depends on the app being unlocked rather
# than on the key being readable -- the same failure IdentityAgent none already
# prevents for pushes, and observed directly: while the app was locked every
# signature failed with
#
#   error: Couldn't sign message (signer): agent refused operation
#
# (a key the agent does not hold blocks instead, waiting on a prompt that a
# launchd job or a headless session has nobody to answer), and all of it began
# working the moment the app was unlocked.
#
# Clearing the variable for this one call sends ssh-keygen to user.signingkey
# instead. Only signing comes through here -- git runs `ssh` itself for fetch
# and push -- so the agent keeps serving connections exactly as before.
#
# Resolved on PATH rather than hardcoded to /usr/bin/ssh-keygen: --env personal
# is not macOS-only. Safe from recursing into itself, since this is not the name
# it looks up.
exec env -u SSH_AUTH_SOCK ssh-keygen "$@"
