#!/usr/bin/env python3
"""Adapts Dropbear to the S7's iOS root: usage patch-dropbear.py SRCDIR SHELL

iOS has no /bin/sh and its passwd names it as root's shell; and only root is to log in. Each change must match exactly
once, or the build stops.
"""
import pathlib
import sys

src, shell = pathlib.Path(sys.argv[1]) / "src", sys.argv[2]


def change(name, old, new):
    path = src / name
    text = path.read_text()
    if text.count(old) != 1:
        sys.exit(f"{name}: expected one match of {old!r}, found {text.count(old)}")
    path.write_text(text.replace(old, new))


# every account that Dropbear looks up gets our shell
change("common-session.c", "ses.authstate.pw_shell = m_strdup(pw->pw_shell);",
       f'ses.authstate.pw_shell = m_strdup("{shell}");')
# only uid 0; and our shell is valid without /etc/shells
change("svr-auth.c", "\tsetusershell();\n",
       "\tif (ses.authstate.pw_uid != 0) {\n"
       '\t\tdropbear_log(LOG_WARNING, "only root may log in");\n'
       "\t\tses.authstate.checkusername_failed = 1;\n"
       "\t\treturn DROPBEAR_FAILURE;\n"
       "\t}\n"
       f'\tif (strcmp(usershell, "{shell}") == 0) {{\n'
       "\t\treturn DROPBEAR_SUCCESS;\n"
       "\t}\n"
       "\tsetusershell();\n")
print("dropbear patched")
