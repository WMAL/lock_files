#!/usr/bin/env python
'''
Encrypt and decrypt files using AES encryption and a common
password. You can use it lock files before they are uploaded to
storage services like DropBox or Google Drive.

The password can be stored in a safe file, specified on the command
line or it can be manually entered each time the tool is run.

Here is how you would use this tool to encrypt a number of files using
a local, secure file. You can optionally specify the --lock switch but
since it is the default, it is not necessary.

   $ lock_files.py file1.txt file2.txt dir1 dir2
   Password: secret
   Re-enter password: secret

When the lock command is finished all of files will be locked (encrypted,
with a ".locked" extension).

You can lock the same files multiple times with different
passwords. Each time lock_files.py is run in lock mode, another
".locked" extension is appended. Each time it is run in unlock mode, a
".locked" extension is removed. Unlock mode is enabled by specifying
the --unlock option.

Of course, entering the password manually each time can be a challenge.
It is normally easier to create a read-only file that can be re-used.
Here is how you would do that.

   $ cat >password-file
   thisismysecretpassword
   EOF
   $ chmod 0600 password-file

You can now use the password file like this to lock and unlock a file.

   $ lock_files.py -p password-file file1.txt
   $ lock_files.py -p password-file --unlock file1.txt.locked

In decrypt mode the tool walks through the specified files and
directories looking for files with the .locked extension and unlocks
(decrypts) them.

Here is how you would use this tool to decrypt a file, execute a
program and then re-encrypt it when the program exits.

   $ # the unlock operation removes the .locked extension
   $ lock_files -p ./password --unlock file1.txt.locked
   $ edit file1.txt
   $ lock_files -p ./password file1.txt

The tool checks each file to make sure that it is writeable before
processing. If any files is not writeable, the program reports an
error and exits unless you specify --cont in which case it
reports a warning that the file will be ignored and continues.

If you want to change a file in place you can use --inplace mode.
See the documentation for that option to get more information.
'''
import argparse
import base64
import getpass
import inspect
import os
import sys

# You may get into trouble with versions of python earlier than 2.7.
try:
    from Crypto import Random
    from Crypto.Cipher import AES
except ImportError as exc:
    print('ERROR: Import failed, you may need to run "pip install pycrypto".\n{:>7}{}'.format('', exc))
    sys.exit(1)

try:
    import Queue as queue  # python 2
except ImportError:
    import queue   # python3


VERSION = '1.0'


# CITATION: http://stackoverflow.com/questions/12524994/encrypt-decrypt-using-pycrypto-aes-256
class AESCipher:
    '''
    Class that provides an object to encrypt or decrypt a string.
    '''
    def __init__(self, key):
        self.m_bs = 32

        # Pad contains the character which is also the number of
        # padded characters. This is how we unpad to work properly.
        self.m_pad = []
        if sys.version_info[0] == 3:
            # Python3 - pad with bytes
            for i in range(self.m_bs + 1):  # include 32
                b = bytes([i]).decode('utf-8') * i
                self.m_pad.append(str(b))
            b = bytes([self.m_bs]).decode('utf-8') * self.m_bs
            self.m_pad[0] = b * self.m_bs # special case
        elif sys.version_info[0] == 2:
            # Python - pad with chars
            for i in range(self.m_bs + 1):  # include 32
                b = chr(i) * i
                self.m_pad.append(b)
            self.m_pad[0] = chr(self.m_bs) * self.m_bs # special case

        if len(key) >= self.m_bs:
            self.m_key = key[:self.m_bs]
        else:
            self.m_key = self._pad(key)

    def encrypt(self, raw):
        raw = self._pad(raw)
        iv = Random.new().read(AES.block_size)
        cipher = AES.new(self.m_key, AES.MODE_CBC, iv)
        return base64.b64encode(iv + cipher.encrypt(raw))

    def decrypt(self, enc):
        enc = base64.b64decode(enc)
        iv = enc[:AES.block_size]
        cipher = AES.new(self.m_key, AES.MODE_CBC, iv)
        return self._unpad(cipher.decrypt(enc[AES.block_size:]))

    def _pad(self, s):
        # pad to the boundary.
        b = len(s) % self.m_bs
        p = self.m_bs - b

        # Works for python3 and python2.
        if isinstance(s, str):
            s += self.m_pad[p]
        elif isinstance(s, bytes):
            ps = self.m_pad[p]
            s += bytes(ps, 'utf-8')
        else:
            assert False
        return s

    def _unpad(self, s):
        # we padded with the number of characters to unpad.
        # just get it and truncate the string.
        # Works for python3 and python2.
        if isinstance(s, str):
            u = ord(s[-1])
        elif isinstance(s, bytes):
            u = s[-1]
        else:
            assert False
        return s[:-u]


# ================================================================
#
# Message Utility Functions.
#
# ================================================================
def _msg(msg, prefix, level=2, ofp=sys.stdout):
    '''
    Display a simple information message with context information.
    '''
    frame = inspect.stack()[level]
    #fname = os.path.basename(frame[1])
    lineno = frame[2]
    ofp.write('{}:{} {}\n'.format(prefix, lineno, msg))


def info(msg, level=1, ofp=sys.stdout):
    '''
    Display a simple information message with context information.
    '''
    _msg(prefix='INFO', msg=msg, level=level+1, ofp=ofp)


def infov(opts, msg, level=1, ofp=sys.stdout):
    '''
    Display a simple information message with context information.
    '''
    if opts.verbose:
        _msg(prefix='INFO', msg=msg, level=level+1, ofp=ofp)


def infov2(opts, msg, level=1, ofp=sys.stdout):
    '''
    Display a simple information message with context information.
    '''
    if opts.verbose > 1:
        _msg(prefix='INFO', msg=msg, level=level+1, ofp=ofp)


def err(msg, level=1, ofp=sys.stdout):
    '''
    Display error message with context information and exit.
    '''
    _msg(prefix='ERROR', msg=msg, level=level+1, ofp=ofp)
    sys.exit(1)


def errn(msg, level=1, ofp=sys.stdout):
    '''
    Display error message with context information but do not exit.
    '''
    _msg(prefix='ERROR', msg=msg, level=level+1, ofp=ofp)


def warn(msg, level=1, ofp=sys.stdout):
    '''
    Display error message with context information but do not exit.
    '''
    _msg(prefix='WARNING', msg=msg, level=level+1, ofp=ofp)


# ================================================================
#
# Program specific functions.
#
# ================================================================
def get_cont_fct(opts):
    '''
    Get the message function: error or warning depending on
    the --cont setting.
    '''
    if opts.cont is True:
        return warn
    return err


def check_existence(opts, path):
    '''
    Check to see if a file exists.
    If -o or --overwrite is specified, we don't care if it exists.
    '''
    if opts.overwrite is False and os.path.exists(path):
        get_cont_fct(opts)('file exists, cannot continue: {}'.format(path))


def read_file(opts, path, stats):
    '''
    Read the file contents.
    '''
    try:
        with open(path, 'rb') as ifp:
            data = ifp.read()
            stats['read'] += len(data)
            return data
    except IOError as exc:
        get_cont_fct(opts)('failed to read file "{}": {}'.format(path, exc))
        return None


def write_file(opts, path, content, stats):
    '''
    Write the file.
    '''
    try:
        with open(path, 'wb') as ofp:
            ofp.write(content)
            stats['written'] += len(content)
    except IOError as exc:
        get_cont_fct(opts)('failed to write file "{}": {}'.format(path, exc))
        return False
    return True


def lock_file(opts, password, path, stats):
    '''
    Lock a file.
    '''
    out = path + opts.suffix
    infov2(opts, 'lock "{}" --> "{}"'.format(path, out))
    check_existence(opts, out)
    content = read_file(opts, path, stats)
    if content is not None:
        try:
            aes = AESCipher(password)
            data = aes.encrypt(content)
            if write_file(opts, out, data, stats) is True:
                if out != path:
                    os.remove(path)  # remove the input
                stats['locked'] += 1
        except ValueError as exc:
            get_cont_fct(opts)('lock/encrypt operation failed for "{}": {}'.format(path, exc))


def unlock_file(opts, password, path, stats):
    '''
    Unlock a file.
    '''
    if path.endswith(opts.suffix):
        if len(opts.suffix) > 0:
            out = path[:-len(opts.suffix)]
        else:
            out = path
        infov2(opts, 'unlock "{}" --> "{}"'.format(path, out))
        check_existence(opts, out)
        content = read_file(opts, path, stats)
        if content is not None:
            try:
                aes = AESCipher(password)
                data = aes.decrypt(content)
                if write_file(opts, out, data, stats) is True:
                    if out != path:
                        os.remove(path)  # remove the input
                    stats['unlocked'] += 1
            except ValueError as exc:
                get_cont_fct(opts)('unlock/decrypt operation failed for "{}": {}'.format(path, exc))
    else:
        infov2(opts, 'skip "{}"'.format(path))
        stats['skipped'] += 1


def process_file(opts, password, path, stats):
    '''
    Process a file.
    '''
    stats['files'] += 1
    if opts.lock is True:
        lock_file(opts, password, path, stats)
    else:
        unlock_file(opts, password, path, stats)


def process_dir(opts, password, path, stats):
    '''
    Process a directory, we always start at the top level.
    '''
    stats['dirs'] += 1
    if opts.no_recurse is False:
        # Recurse to get everything.
        for root, subdirs, subfiles in os.walk(path):
            for subfile in sorted(subfiles, key=str.lower):
                if subfile.startswith('.'):
                    continue
                subpath = os.path.join(root, subfile)
                process_file(opts, password, subpath, stats)
    else:
        # Use listdir() to get the files in the current directory only.
        for entry in sorted(os.listdir(path), key=str.lower):
            if entry.startswith('.'):
                continue
            subpath = os.path.join(path, entry)
            if os.path.isfile(subpath):
                process_file(opts, password, subpath, stats)


def process(opts, password, entry, stats):
    '''
    Process an entry.

    If it is a file, then operate on it.

    If it is a directory, recurse unless --no-recurse was specified.
    '''
    if os.path.isfile(entry):
        process_file(opts, password, entry, stats)
    elif os.path.isdir(entry):
        process_dir(opts, password, entry, stats)


def run(opts, password):
    '''
    Process the entries on the command line.
    They can be either files or directories.
    '''
    stats = {
        'locked': 0,
        'unlocked': 0,
        'skipped': 0,
        'files': 0,
        'dirs': 0,
        'read': 0,
        'written': 0,
        }

    for entry in opts.FILES:
        process(opts, password, entry, stats)

    # Print the summary statistics.
    if opts.verbose:
        print('total files:         {:>10,}'.format(stats['files']))
        if opts.lock:
            print('total locked:        {:>10,}'.format(stats['locked']))
        if opts.unlock:
            print('total unlocked:      {:>10,}'.format(stats['unlocked']))
        print('total skipped:       {:>10,}'.format(stats['skipped']))
        print('total bytes read:    {:>10,}'.format(stats['read']))
        print('total bytes written: {:>10,}'.format(stats['written']))


def get_password(opts):
    '''
    Get the password.

    If the user specified -P or --password on the command line, use
    that.

    If the user speciried -p <file> or --password-file <file> on the
    command line, read the first line of the file that is not blank or
    starts with #.

    If neither of the above, prompt the user twice.
    '''
    # User specified it on the command line. Not safe but useful for testing
    # and for scripts.
    if opts.password:
        return opts.password

    # User specified the password in a file. It should be 0600.
    if opts.password_file:
        if os.path.exists(opts.password_file):
            err("password file doesn't exist: {}".format(opts.password_file))
        password = None
        ifp = open(opts.password_file, 'rb')
        for line in ifp.readlines():
            line.strip()  # leading and trailing white space not allowed
            if len(line) == 0:
                continue  # skip blank lines
            if line[0] == '#':
                continue  # skip comments
            password = line
            break
        ifp.close()
        if password is None:
            err('password was not found in file ' + opts.password_file)
        return password

    # User did not specify a password, prompt twice to make sure that
    # the password is specified correctly.
    password = getpass.getpass('Password: ')
    password2 = getpass.getpass('Re-enter password: ')
    if password != password2:
        err('passwords did not match!')
    return password


def getopts():
    '''
    Get the command line options.
    '''
    def gettext(s):
        lookup = {
            'usage: ': 'USAGE:',
            'positional arguments': 'POSITIONAL ARGUMENTS',
            'optional arguments': 'OPTIONAL ARGUMENTS',
            'show this help message and exit': 'Show this help message and exit.\n ',
        }
        return lookup.get(s, s)

    argparse._ = gettext  # to capitalize help headers
    base = os.path.basename(sys.argv[0])
    name = os.path.splitext(base)[0]
    usage = '\n  {0} [OPTIONS] [<FILES_OR_DIRS>]+'.format(base)
    desc = 'DESCRIPTION:{0}'.format('\n  '.join(__doc__.split('\n')))
    epilog = r'''EXAMPLES:
   # Example 1: help
   $ {0} -h

   # Example 2: lock/unlock a single file
   $ {0} -P 'secret' file.txt
   $ ls file.txt*
   file.txt.locked
   $ {0} -P 'secret' --unlock file.txt
   $ ls -1 file.txt*
   file.txt

   # Example 3: lock/unlock a set of directories
   $ {0} -P 'secret' project1 project2
   $ find project1 project2 --type f -name '*.locked'
   <output snipped>
   $ {0} -P 'secret' --unlock project1 project2

   # Example 4: lock/unlock using a custom extension
   $ {0} -P 'secret' -s .EncRypt file.txt
   $ ls file.txt*
   file.txt.EncRypt
   $ {0} -P 'secret' -s .EncRypt --unlock file.txt

   # Example 5: lock/unlock a file in place (using the same name)
   #            The file name does not change but the content.
   #            It is compatible with the default mode of operation in
   #            previous releases.
   #            This mode of operation is not recommended because
   #            data will be lost if the disk fills up during a write.
   $ {0} -P 'secret' -i -l file.txt
   $ ls file.txt*
   file.txt
   $ {0} -P 'secret' -i -u file.txt
   $ ls file.txt*
   file.txt

   # Example 6: use a password file.
   $ echo 'secret' >pass.txt
   $ chmod 0600 pass.txt
   $ {0} -p pass.txt -l file.txt
   $ {0} -p pass.txt -u file.txt.locked

COPYRIGHT:
   Copyright (c) 2015 Joe Linoff, all rights reserved

LICENSE:
   MIT Open Source

PROJECT:
   https://github.com/jlinoff/lock_files
 '''.format(base)
    afc = argparse.RawTextHelpFormatter
    parser = argparse.ArgumentParser(formatter_class=afc,
                                     description=desc[:-2],
                                     usage=usage,
                                     epilog=epilog)

    group1 = parser.add_mutually_exclusive_group()

    # Note that I cannot use --continue here because opts.continue
    # would try to reference a python keyword 'continue' and fail.
    parser.add_argument('-c', '--cont',
                        action='store_true',
                        help='''Continue if a single file lock/unlock fails.
Normally if the program tries to modify a fail and that modification
fails, an error is reported and the programs stops. This option causes
that event to be treated as a warning so the program continues.
 ''')

    parser.add_argument('-d', '--decrypt',
                        action='store_true',
                        help='''Unlock/decrypt files.
This option is deprecated.
It is the same as --unlock.
 ''')

    parser.add_argument('-e', '--encrypt',
                        action='store_true',
                        help='''Lock/encrypt files.
This option is deprecated.
This is the same as --lock and is the default.
 ''')

    parser.add_argument('-i', '--inplace',
                        action='store_true',
                        help='''In place mode.
Overwrite files in place.

It is the same as specifying:
   -o -s ''

This is a dangerous because a disk full operation can cause data to be
lost when a write fails. This allows you to duplicate the behavior of
the previous version.
 ''')

    parser.add_argument('-l', '--lock',
                        action='store_true',
                        help='''Lock files.
Files are locked and the ".locked" extension is appended unless
the --suffix option is specified.
 ''')

    parser.add_argument('-o', '--overwrite',
                        action='store_true',
                        help='''Overwrite files that already exist.
This can be used in conjunction disable file existence checks.
It is used by the --inplace mode.
 ''')

    parser.add_argument('-n', '--no-recurse',
                        action='store_true',
                        help='''Do not automatically recurse into subdirectories.
 ''')

    group1.add_argument('-p', '--password-file',
                        action='store',
                        type=str,
                        help='''file that contains the password.
The default behavior is to prompt for the password.
 ''')

    group1.add_argument('-P', '--password',
                        action='store',
                        type=str,
                        help='''Specify the password on the command line.
This is not secure because it is visible in the command history.
 ''')

    parser.add_argument('-s', '--suffix',
                        action='store',
                        type=str,
                        default='.locked',
                        metavar=('EXTENSION'),
                        help='''Specify the extension used for locked files.
Default: %(default)s
 ''')

    parser.add_argument('-u', '--unlock',
                        action='store_true',
                        help='''Unlock files.
Files with the ".locked" extension are unlocked.
If the --suffix option is specified, that extension is used instead of ".locked".
 ''')

    parser.add_argument('-v', '--verbose',
                        action='count',
                        default=0,
                        help='''Increase the level of verbosity.
A single -v generates a summary report.
Two or more -v options show all of the files being processed.
 ''')

    # Display the version number and exit.
    parser.add_argument('-V', '--version',
                        action='version',
                        version='%(prog)s version {0}'.format(VERSION),
                        help="""Show program's version number and exit.
 """)

    # Positional arguments at the end.
    parser.add_argument('FILES',
                        nargs="*",
                        help='files to process')

    opts = parser.parse_args()

    # Make lock and unlock authoritative.
    if opts.decrypt is True:
        opts.unlock = True
    if opts.encrypt is True:
        opts.lock = True
    if opts.lock is True and opts.unlock is True:
        error('You have specified mutually exclusive options to lock/encrypt and unlock/decrypt.')
    if opts.lock is False and opts.unlock is False:
        opts.lock = True  # the default
    if opts.inplace:
        opts.suffix = ''
        opts.overwrite = True
    return opts


def main():
    '''
    main
    '''
    opts = getopts()
    password = get_password(opts)
    run(opts, password)


if __name__ == '__main__':
    main()
