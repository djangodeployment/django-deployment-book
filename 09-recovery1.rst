Recovery part 1
===============

Why "recovery"?
---------------

Usually book chapters and blog posts dealing with what I'm dealing in
this chapter call it "backup and recovery". To me, backup is just a part
of recovery, it is only the first step towards recovery. This is why I
prefer to just use "recovery". It's not just a language issue, it's a
different way of thinking. When you deal with "backup and recovery", you
view them as two separate things. You might finish your backup and think
"I'm through with this, I'll deal with recovery if and when the time
comes". When we name it just "recovery", you understand that backup
isn't something isolated, and certainly it isn't the point. Backup on
its own is useless and pointless. Your customer doesn't care about
backup; they care about whether you are able to recover the system when
it breaks. In fact, they don't even care about that; they just care that
the system works, and they prefer to not know what you are doing behind
the scenes for it to work. One of the things you are doing behind the
scenes is to recover the system.

The most important thing about recovery is that it should be tested.
Once a year, or once in two years, you should switch off the server,
pretend it exploded, and recover on a new server. Without doing this,
you will not know if you can recover. Recovery plans contain all sorts
of silly errors. Maybe your backups are encrypted, and the decryption
key is only stored in the server itself, and you won't have it when you
need to recover. Maybe you don't backup some files that you think can be
recreated, and it turns that among them there are some valuable data
files. The thing is, you won't be able to know what you did wrong until
you test your recovery.

Untested recovery always takes way longer than you think. When you have
written down the recovery procedure and you have tested it, you may be
able to recover within a couple of hours or even a few minutes, with
minimal stress. It can be part of your day-to-day work and not a huge
event. Without a written procedure, or with an untested procedure, you
will be sweating over your keyboard for a whole day or more, while your
customer will be frustrated. It's hard to imagine how much time you can
waste because you are getting a ``pg_restore`` option wrong until you
try it.

So, **think about recovery. Recovery starts with backup, continues with
the creation of a written restore procedure, and is mostly completed
when that procedure is tested.** Anything less than that is dangerous.

Where to backup
---------------

The cloud is very attractive. Amazon, Google, Backblaze, Microsoft, they
sell cheap storage. All your server has to do is save its stuff there.
You don't need to change tapes every day and move them off site, as we
used to do 10 years ago. And your backup is on another continent. No
chance it will explode the same time as your server, right? Wrong!

The problem is that your system has a single point of failure: the
security of your server. For your server to backup itself to the remote
storage, it must have write access to the remote storage. So if the
security of your server is compromised, the attacker can delete your
server's data *and* the backup.

Do you think this is far-fetched? Code Spaces was a company that had its
code and data on Amazon Web Services. One day in 2014 an attacker
managed to get access to their account and demanded ransom. Negotiations
didn't go well and the attacker deleted all data. All backups.
Everything. The company was wiped out overnight. It ceased to exist.
Undoubtedly its customers were also damaged.

Forget about two-factor authentication or Amazon's undeletable S3 files.
Your phone might be stolen. Or the employee who has access to the
account *and* has two factor-authentication on his phone might go crazy
and want to harm you.  Or *you* might go crazy and want to hurt your
customers. Or you might be paying the server and the backup from the
same credit card, with the same obsolete email in both, and the credit
card might be cancelled, and you'd fail to receive the emails, and the
providers might delete the server and the backups at the same time.  Or
the whole system, regardless its safety checks and everything, might
have a bug somewhere. Our experience of the last 20 years does not
indicate that systems are getting safer; on the contrary.  Heartbleed_
and Shellshock_ showed how vulnerable the whole Internet is; and the
next such problem is just waiting to be discovered.

The only way to be reasonably certain that your data is safe is if the
backup is offline, on a medium you can actually touch, disconnected from
the network. But this is very expensive, so you need to compromise on
something.

What I do is backup my systems online daily, but I also copy the backup
to a disk once a month, and I take the disk offline. The next month I
use another disk. I will tell you more about it later on.

.. _heartbleed: https://en.wikipedia.org/wiki/Heartbleed
.. _shellshock: https://en.wikipedia.org/wiki/Shellshock_%28software_bug%29

Estimating storage cost
-----------------------

Cloud storage services advertise a cost per GB per month. For example,
for Backblaze the amount at the time of this writing is $0.005. We need
to multiply this by 12 to arrive at a cost of $0.06 per year.

Depending on the backup scheme you use, you might save the data multiple
times. For example, the scheme I will propose involves a full backup
every three months, and backups kept for two years. This means that each
GB will be stored a total of eight times. So this means that each GB of
data, or eight GB of backup storage, will cost $0.48 per year.

There are also charges for downloading. Backblaze charges $0.05 per GB
for each download.  If you download the backups twice a year for
recovery testing, that's $0.10. So the total so far is $0.58 per GB per
year. For a Django installation with 10 GB of data, this will be $5.80
per year.  For 30 GB of data, it will be $17.40 per year. While it is
not much, if you maintain many Django installations it can add up, so
you must make sure you take the cost into account when you offer a
support contract to the customer.

If you download the backups once a month in order to save them to an
offline disk, this will cost an additional $0.05 per month, which
amounts to $0.60 per year, so this doubles online storage costs. In the
scheme I explain in the next chapter, we take offline backups directly
from the server, not from the online backups, so you don't have this
cost. However, it's perfectly valid to backup the backups instead, and
sometimes it's preferable; if you do it this way, don't forget to take
the download cost into account.

If you use external disks for offline backups, you need two disks, and
each disk must have a capacity of all the data of all your installations
combined. They must be rotating disks (i.e. not SSD), preferably
portable USB ones.  You may also be able to use SATA disks with a
SATA-to-USB adapter; however, one of the advantages of USB disks is that
it's much easier to label them by attaching a sticker (SATA disks have
very little space available for attaching a sticker, unless you cover
their original label, which you don't want). You might want to use small
(2.5-inch) disks, which are much easier to carry. In any case, in this
book we deal with deployments on a single server, so these are probably
small and a 1 TB disk is likely enough for all your deployments. Two
such external disks cost around $100. They might live for five years,
but I prefer to be more conservative and assume they'll last for a
maximum of two years; your backup schemes, your customers, and your
business in general will have changed enough by then. So the total cost
of backup (assuming it all fits in a 1 TB disk) is $50 per year plus
$0.58 per GB per year.

Setting up backup storage
-------------------------

How exactly you will setup your backup storage depends on the type of
storage you use. You might use Backblaze B2, Google Cloud Storage,
Amazon S3, or various other services. If you have a static IP address,
you could also setup a physical machine, but this is typically harder
and more expensive. In the rest of this chapter, I will assume you are
using Backblaze B2. If you are familiar with another storage system, go
ahead and use that. (Note: I am not affiliated with Backblaze.)

To setup your backup storage on Backblaze, go to https://backblaze.com/,
select "B2 Cloud Storage", and sign up or login. Then create a bucket.

A bucket is a virtual hard disk, so to speak. It has no fixed size; it
grows as you add files to it. Rather than having different buckets for
different customers, in this chapter I assume you have only one bucket,
which is simpler. Remember, always choose the simplest solution first,
and don't make assumptions about how the future will be; very often you
ain't gonna need it. If and when the future brings in needs that can't
be covered by the solution I'm proposing here, you will need to revise
your strategy.

In order to create the bucket, you will be asked for a name, and about
whether it's going to be private or public. It will be private of
course; as for the name, I like ``$NICK-backup``, where ``$NICK`` is my
usual username (such as the one you have on Twitter perhaps). After you
create it, go to the Bucket Settings, and tell it to keep only the last
version of the file versions. This is because whenever you change a
file, or whenever you delete a file, Backblaze B2 has the option of also
keeping the previous version of the file. While this can be neat in some
use cases, we won't be needing it here and it's going to be a waste of
disk space (and therefore money). We just want the bucket to behave like
a normal hard disk.

Now, if you go to the "Buckets" section of the Backblaze B2 dashboard
("Buckets" is actually the front page of the dashboard), near the top it
says "Show Accout ID and Application Key". Click on that link and it
will show you your Account ID. If you don't know your Application Key
(for example, if it's your first time in Backblaze B2) create a new one.
Take note of both your Account ID and your Application Key; we will need
them later. I will be calling them $ACC_ID and $APP_KEY.

.. _setting_up_duplicity_and_duply:

Setting up duplicity and duply
------------------------------

The recovery software we will use is duplicity. While it works quite
well, it is hard to use on its own because its user interface is
inconvenient. It does not have a configuration file, but you tell it
everything it needs to know on the command line, and a very long command
line indeed.  I believe that the authors of duplicity intended it to be
run by scripts and not by humans.  Here we are going to use duply, a
front-end to duplicity that makes our job much easier. Let's start by
installing it:

.. code-block:: bash

    apt install duply

.. _installing_duplicity_in_debian:

.. hint:: Installing duplicity in Debian

   Although ``apt install duply`` will work on Debian 8, it will install
   duplicity 0.6.24, which does not support Backblaze B2. Therefore, you
   may want to install a more recent version of duplicity.

   Go to duplicity's home page, http://duplicity.nongnu.org/, and copy
   the link to the current release in the Download section. I will call
   it $DUPLICITY_TARBALL_SOURCE, and I will also use the placeholder
   $DUPLICITY_VERSION.

   Install duplicity with the following commands:

   .. code-block:: bash

      apt install python-dev build-essential \
          python-setuptools librsync-dev
      cd
      wget $DUPLICITY_TARBALL_SOURCE
      tar xzf duplicity-$DUPLICITY_VERSION.tar.gz
      cd duplicity-$DUPLICITY_VERSION
      python setup.py install

   ``wget`` downloads stuff from the web. You give it a URL, it fetches
   it and stores it in a file. In this case, it will fetch file
   ``duplicity-$DUPLICITY_VERSION.tar.gz`` and store it in the current
   directory (which should be ``/root`` if you run ``cd`` as I
   suggested).

   ``tar`` is very roughly the equivalent of ``zip``/``unzip`` on Unix;
   it can create and read files containing other files (but ``tar``
   can't read zip files, neither can ``zip`` read tar files). These
   files are called "archive files". The ``x`` in ``xzf`` means that the
   desired operation is extraction of files from an archive (as opposed
   to ``c``, which is the creation of an archive, or ``t``, which is for
   listing the contents of an archive); the ``z`` means that the archive
   is compressed; and ``f`` means that "the next argument in the command
   line is the archive name". I have long forgotten what it does if you
   don't specify the ``f`` option, but the default was something
   suitable for 1979, when the first version of ``tar`` was created and
   had to do with tape drives (in fact "tar" is short for "tape
   archiver"). If more arguments follow, they are names of files to
   extract from the archive. Since we don't specify any, it will extract
   all files. In this particular archive, all contained files are in
   directory ``duplicity-$DUPLICITY_VERSION``, so ``tar`` creates the
   directory to put the files in there.

Next, let's create a configuration directory:

.. code-block:: bash

    mkdir -p /etc/duply/main
    chmod 700 /etc/duply/main

With duply you can create many different configurations which it calls
"profiles". We only need one here, and we will call it "main".  This is
why we created directory ``/etc/duply/main``. Inside it, create a file
called ``conf``, with the following contents:

.. code-block:: bash

    GPG_KEY=disabled

    SOURCE=/
    TARGET=b2://$ACC_ID:$APP_KEY@$NICK-backup/$SERVER_NAME/

    MAX_AGE=2Y
    MAX_FULLS_WITH_INCRS=2
    MAX_FULLBKP_AGE=3M
    DUPL_PARAMS="$DUPL_PARAMS --full-if-older-than $MAX_FULLBKP_AGE "

    VERBOSITY=warning
    ARCH_DIR=/var/cache/duplicity/duply_main/

.. _syntax_is_bash:

.. warning:: Syntax is bash

   The duply configuration file is neither Python (such as
   ``settings.py``) nor an ini-style file; it is a shell script. This
   notably means that, when defining variables, there can be no space on
   either side of the equals sign ('='). Strings need to be quoted only
   if they contain spaces, so, for example, the following three
   definitions are exactly the same:

   .. code-block:: bash

      GREETING=hello
      GREETING="hello"
      GREETING='hello'

   However, variables are replaced inside double quotes, but not inside
   single quotes:

   .. code-block:: bash

      WHO=world
      GREETING1="hello, $WHO"
      GREETING2='hello, $WHO'
   
   After this is run, ``GREETING1`` will have the value "hello, world",
   whereas ``GREETING2`` will be "hello, $WHO". You can experiment by
   simply typing these commands in the shell prompt, and examine the
   values of variables with ``echo $GREETING1`` and so on.

Also create a file ``/etc/duply/main/exclude``, with the following
contents::

    - /dev
    - /proc
    - /sys
    - /run
    - /var/lock
    - /var/run
    - /lost+found
    - /boot
    - /tmp
    - /var/tmp
    - /media
    - /mnt
    - /var/cache
    - /var/crash
    - /var/swap
    - /var/swapfile
    - /var/swap.img
    - /var/lib/mysql
    - /var/lib/postgresql

You can now backup your system by executing this command:

.. code-block:: bash

   duply main backup

If this is a small virtual server, it should finish in a few minutes.
**This, however, is just a temporary test.** There are many things that
won't work correctly, and one of the most important is that we haven't
backed up PostgreSQL (and MySQL, if you happen to use it), and any
SQLite files we backed up may be corrupted. We just made this test to
get you up and running.  Let me now explain what these configuration
files mean.

Duply configuration
-------------------

Let's check again the duply configuration file,
``/etc/duply/main/conf``:

.. code-block:: bash

    GPG_KEY=disabled

    SOURCE=/
    TARGET=b2://$ACC_ID:$APP_KEY@$NICK-backup/$SERVER_NAME/

    MAX_AGE=2Y
    MAX_FULLS_WITH_INCRS=2
    MAX_FULLBKP_AGE=3M
    DUPL_PARAMS="$DUPL_PARAMS --full-if-older-than $MAX_FULLBKP_AGE "

    VERBOSITY=warning
    ARCH_DIR=/var/cache/duplicity/duply_main/

**GPG_KEY=disabled**
    Duplicity, and therefore duply, can encrypt the backups. The
    rationale is that the backup storage provider shouldn't be able to
    read your files. So if you have a company, and you have a server at
    the company premises, and you backup the server at Backblaze or at
    Google, you might not want Backblaze or Google to be able to read
    the company's files. In our case this would achieve much less. Our
    virtual server provider can read our files anyway, since they are
    stored in our virtual server, in a data centre owned by the
    provider. Making it impossible for Backblaze to read our files
    doesn't achieve much if Digital Ocean can read them. Encrypting the
    backups is often more trouble than what it's worth, so we just
    disable it.

**SOURCE=/**
    This specifies the directory to backup. We specify the root
    directory in order to backup the entire file system. We will
    actually exclude some files and directories as I explain in the next
    section.

**TARGET=b2://...**
    This is the place to backup to. The first part, ``b2:``, specifies
    the "storage backend". Duplicity supports many storage backends;
    they are listed in ``man duplicity``, Section "URL Format". As you
    can see, the syntax for the Backblaze B2 backend is
    "b2://account_id:application_key@bucket/directory". Even if you have
    only one server, it's likely that soon you will have more, so store
    your backups in the $SERVER_NAME directory.

**MAX_AGE=2Y**
    This means that backups older than 2 years will be deleted. Note
    that, if your databases and files contain customer data, it may be
    illegal to keep the backups for more than a specified amount of
    time. If a user decides to unsubscribe or otherwise remove their
    data from your database, you are often required to delete every
    trace of your customer's data from everywhere, including the
    backups, within a specified amount of time, such as six months or
    two years. You need to check your local privacy laws.

**MAX_FULLS_WITH_INCRS=2**, **MAX_FULLBKP_AGE=3M**
    A **full backup** backs up everything. In an **incremental backup**
    only the things that have changed since the previous backup are
    backed up. So if on 12 January you perform a full backup, an
    incremental backup on 13 January will only save the things that have
    changed since 12 January, and another incremental on 14 January will
    only save what has changed since 13 January. ``MAX_FULLBKP_AGE=3M``
    means that every three months a new full backup will occur.
    ``MAX_FULLS_WITH_INCRS=2`` means that incremental backups will be
    kept only for the last two full backups; for older full backups,
    incrementals will be removed.
    
    Collectively these parameters (together with ``MAX_AGE=2Y``) mean
    that a total of about eight full backups will be kept; for the most
    recent three to six months, the daily history of the files will be
    kept, whereas for older backups the quarterly history will be kept.
    You will thus be able to restore your system to the state it was two
    days ago, or three days ago, or 58 days ago, but not necessarily
    exactly 407 days ago—you will need to round this up to about 45 days
    earlier or later.

    Keeping the history of your system is very important. It is common
    to lose some data and realize it some time later. If each backup
    simply overwrote the previous one, and you realized today that you
    had accidentally deleted a file four days ago, you'd be in trouble.

**DUPL_PARAMS="$DUPL_PARAMS ..."**
    If you want to add any parameters to duplicity that have not been
    foreseen in duply, you can specify them in ``DUPL_PARAMS``. Duply
    just takes the value of ``DUPL_PARAMS`` and adds it to the duplicity
    command line. Duply does not directly support ``MAX_FULLBKP_AGE``,
    so we need to manually add it to ``DUPL_PARAMS``.

    The ``$DUPL_PARAMS`` and ``$MAX_FULLBKP_AGE`` should be included
    literally in the file, the aren't placeholders such as ``$NICK``,
    ``$ACC_ID`` and ``$APP_KEY``
    
**VERBOSITY=warning**
    Options are error, warning, notice, info, and debug. "warning" will
    show warnings and errors; "notice" will show notices and warnings
    and errors; and so on. "warning" is usually fine.

**ARCH_DIR=/var/cache/duplicity/duply_main/**
    Duplicity keeps a cache on the local machine that helps it know what
    things it has backed up, without actually needing to fetch that
    information from the backup storage—this speeds things up and
    lessens network traffic. If this local cache is deleted, it
    recreates it by reading stuff from remotely. Duply's default cache
    path is suboptimal so we change it.

In order to see duply's documentation for these settings you need to ask
it to create a configuration file. We created the configuration files
above ourselves, but we could have given the command ``duply main
create``, and this would have created ``/etc/duply/main/conf`` and
``/etc/duply/main/exclude``; actually it creates these files under
``/etc/duply`` only if that directory exists; otherwise it creates them
under ``~/.duply``. After it creates the files, you are supposed to go
and edit them. The automatically created ``conf`` is heavily commented
and the comments explain what each setting does. So if you want to read
the docs, ``duply tmp create``, then go to ``/etc/duply/tmp/conf`` and
read.

When you run duply what it actually does is read your configuration
files, convert them into command line arguments for duplicity, and
execute duplicity with a huge command line. For this reason, the
documentation of duply's settings often refers you to duplicity. For
example, for details on ``MAX_FULLS_WITH_INCRS``, the comments in
``conf`` tell you to execute ``man duplicity`` and read about
``remove-all-inc-of-but-n-full``.

Excluding files
---------------

The file ``/etc/duply/main/exclude`` contains files and directories that
shall be excluded from the backup. Actually it uses a slightly
complicated language that allows you to say things like "exclude
directory X but include X/Y but do not include X/Y/Z". However, we will
use it in a simple way, just in order to exclude files and directories,
which means we just precede each path with "-". The exclude file we
specified two sections ago is this::

    - /dev
    - /proc
    - /sys
    - /run
    - /var/lock
    - /var/run
    - /lost+found
    - /boot
    - /tmp
    - /var/tmp
    - /media
    - /mnt
    - /var/cache
    - /var/crash
    - /var/swap
    - /var/swapfile
    - /var/swap.img
    - /var/lib/mysql
    - /var/lib/postgresql

**/dev, /proc, /sys**
   In these directories you will not find real files. ``/dev`` contains
   device files. In Unix most devices look like files. In fact, one of
   the Unix principles is that everything is a file. So the first hard
   disk is usually ``/dev/sda`` (but in virtual machines it is often
   ``/dev/vda``). ``/dev/sda1`` (or ``/dev/vda1``) is the first
   partition of that disk. You can actually open ``/dev/sda`` (or
   ``/dev/vda``) and write to it (the root user has permission to do
   so), which will of course corrupt your system. Reading it is not a
   problem though (but it's rarely useful).

   ``/sys`` and ``/proc`` contain information about the system. For
   example, ``/proc/meminfo`` contains information about RAM, and
   ``/proc/cpuinfo`` about the CPU. You can examine the contents of
   these "files" by typing, for example, ``cat /proc/meminfo`` (``cat``
   prints the contents of files).

   The ``/dev``, ``/sys`` and ``/proc`` directories exist on your disk
   only as empty directories. The "files" inside them are created by the
   kernel, and they do not exist on the disk.  Not only does
   it not make sense to backup, you would also be in trouble if you
   attempted to.

**/run, /var/lock, /var/run**
   ``/run`` stores information about running services, in order to keep
   track of them. This information is mostly process ids and locks. For
   example, ``/run/sshd.pid`` contains the process id of the SSH server.
   The system will use this information if, for example, you ask to
   restart the SSH server.  Whenever the system boots, it empties that
   directory, otherwise the system would be confused. In older versions
   such information was stored in ``/var/lock`` and ``/var/run``, which
   are now usually just symbolic links to ``/run`` or to a subdirectory
   of ``/run``.

**/lost+found**
   In certain types of filesystem corruption, fsck (the equivalent of
   Windows checkdsk) puts in there orphan files that existed on the disk
   but did not have a directory entry. I've been using Unix systems for
   25 years now, and I've had plenty of power failures while the system
   was on, and many of them were in the old times without journaling,
   and yet I believe I've only once seen files in that directory, and
   they were not useful to me. It's more a legacy directory, and many
   modern filesystems, such as XFS, don't have it at all. You will not
   use it, let alone back it up.

**/boot**
   This directory contains the stuff essential to boot the system,
   namely the boot loader and the Linux kernel. The installer creates it
   and you normally don't need it in backup.

**/tmp, /var/tmp**
   ``/tmp`` is for temporary files; any file you create there will be
   deleted in the next reboot. If you want to create a temporary file
   that will survive reboots, use ``/var/tmp``.

**/media, /mnt**
   Unlike Windows, where disks and disk-like devices get a letter (C:,
   D:, E: and so on), in Unix there is a single directory tree. There is
   only one ``/bin``. So, assume you have two disks. How do you access
   the second disk? The answer is that you "mount" it on a point of the
   directory tree. For example, a relatively common setup for multiuser
   systems is for the second disk to contain the ``/home`` directory
   with the user data, and for the first disk to contain all the rest.
   In that case, after the system boots, it will mount the second disk
   at ``/home``, so if you ``ls /home`` you will see the contents of the
   second disk (if the first disk also has files inside the ``/home``
   directory, these will become hidden and inaccessible after the second
   disk is mounted).

   The ``/media`` directory is used mostly in desktop systems. If you
   plugin a USB memory stick or a CDROM, it is usually mounted in a
   subdirectory of ``/media``. The ``/mnt`` directory exists only as a
   facility for the administrator, whenever there is a need to
   temporarily mount another disk. These two directories are rarely used
   in small virtual servers.

**/var/cache**
   As its name implies, this directory is for cached data. Anything in
   it can be recreated. Its purpose is to speed things up, for example
   by keeping local copies of things whose canonical position is
   somewhere in the network. It can be quite large and it would be a
   waste of storage to back it up.

**/var/swap, /var/swapfile, /var/swap.img**
   These are nonstandard files that some administrators use for swap
   space (swap space is what Windows incorrectly calls "virtual
   memory"). Swap space is normally placed on dedicated disk partitions.
   If your system doesn't have such files, so much the better, but keep
   these files excluded because in the future you or another
   administrator might create them.

**/var/crash**
   If the system crashes the kernel may dump some debugging information
   in there.

**/var/lib/mysql, /var/lib/postgresql**
   We won't directly backup your databases. Section "Backing up
   databases" explains why and how.

One more directory that is giving me headaches is ``/var/lib/lxcfs``.
Like ``/proc``, it creates error messages when you try to walk through.
It is related to LXC, a virtual machine technology, which seems to be
installed on Ubuntu by default (at least in Digital Ocean). I think it
could be a bad idea to exclude it, in case you start using LXC in the
future and forget it's not being backed up. I just remove LXC with ``apt
purge lxc-common lxcfs`` and I'm done, as this also removes the
directory.

Additional directories for excluding or including
-------------------------------------------------

Your backup system will work well if you exclude only the directories I
already mentioned. In this section I explain what the other directories
are and I discuss whether and under what circumstances they should be
excluded.

**/bin, /lib, /sbin**
   ``/bin`` and ``/sbin`` contain executable programs. For example, if
   you list the contents of ``/bin``, you will find that ``ls`` itself
   is among the files listed. The files in ``/bin`` and ``/sbin`` are
   roughly the equivalent of the .EXE files in ``C:\Windows\System32``.
   The difference between ``/bin`` and ``/sbin`` is that programs in
   ``/bin`` are intended to be run by all users, whereas the ones in
   ``/sbin`` are for administrators only. For example, all users are
   expected to want to list their files with ``ls``, but only
   administrators are expected to partition disks with ``fdisk``, which
   is why ``fdisk`` is ``/sbin/fdisk``.

   ``/lib`` contains shared libraries (the equivalent of Windows Dynamic
   Link Libraries). The files in ``/lib`` are roughly the equivalent of
   the .DLL files in ``C:\Windows\System32``. One difference is that in
   ``C:\Windows\System32`` you may also find DLLs installed by
   third-party software; in ``/lib``, however, there are only shared
   libraries essential for the operation of the system.

   There may also be other ``/lib`` directories, such as ``/lib32`` or
   ``/lib64``. These also contain essential shared libraries. On my
   64-bit systems the libraries are actually in ``/lib``, but there also
   exists ``/lib64``, which only contains a symbolic link to a library
   in ``/lib``. On other systems ``/lib`` may be a symbolic to either
   ``/lib32`` or ``/lib64``. In any case, the system manages all these
   directories itself and we usually don't need to care.

**/etc**
   As we have already said in :ref:`users_and_directories`, ``/etc``
   contains configuration files.

**/home, /root**
   ``/home`` is where user files are stored. It's the equivalent of
   Windows' ``C:\Users`` (formerly ``C:\Documents and Settings``).
   However, the root user doesn't have a directory under ``/home``;
   instead, the home directory for the root user is ``/root``.  Since
   the root user is only meant to do administrative work on a system and
   not to use it and create files like a normal user, the ``/root``
   directory is often essentially empty and unused. However, if you want
   to create some files it's an appropriate place.

   Very often in servers ``/home`` is also empty, since there are no
   real users (people), but this actually depends on how the
   administrator decides to setup the system. For example, some people
   may create a django user with a ``/home/django`` directory and install
   their django project in there. In this book we have created a user,
   but we have been using different directories for the Django project,
   as explained in previous chapters.

**/usr, /opt, /srv**
   ``/usr`` has nothing to do with users, and its name is a historical
   accident. It's the closest thing there is to Windows' ``C:\Program
   Files``. Everything in ``/usr`` is in subdirectories.

   ``/usr/bin``, ``/usr/lib``, and ``/usr/sbin`` are much like ``/bin``,
   ``/lib`` and ``/sbin``. The difference is that the latter contain the
   most essential utilities and libraries of the operating system,
   whereas the ones under ``/usr`` contain stuff from add-on packages
   and the less important utilities. Nowadays the distinction is not
   important, and I think that lately some systems are starting to make
   ``/bin`` a link to ``/usr/bin`` and so on. It used to be important
   when the disks were small and the whole of ``/usr`` was on another
   disk that was being mounted later in the boot process.

   I'm not going to bother you with more details about the ``/usr``
   subdirectories, except ``/usr/local``. Everything installed in
   ``/usr``, except ``/usr/local``, is managed by the Debian/Ubuntu
   package manager.  For example, ``apt`` will install programs in
   ``/usr``, but will not touch ``/usr/local``. Likewise, while you can
   modify stuff inside ``/usr/local``, you should not touch any other
   place under ``/usr``, because this is supposed to be managed only by
   the system's package manager.  The tools you use respect that; for
   example, if you install a Python module system-wide with ``pip``, it
   will install it somewhere under ``/usr/local/lib`` and/or
   ``/usr/local/share``.  ``/usr/local`` has more or less the same
   subdirectories as ``/usr``, and the difference is that only you (or
   your tools) write to ``/usr/local``, and only the system package
   manager writes to the rest of ``/usr``.

   Programs not installed by the system package manager should go either
   to ``/usr/local``, or to ``/opt``, or to ``/srv``. Here is the
   theory:

    - If the program replaces a system program, use ``/usr/local``. For
      example, a few pages ago I explained how we can install duplicity
      on Debian 8. The installation procedure I specified will by
      default put it in ``/usr/local``.

    - If the program, its configuration and its data are to be installed
      in a single directory, it should be a subdirectory of ``/srv``.

    - If the program directories are going to be cleanly separated into
      executables, configuration, and data, the program should go to
      ``/opt`` (and the configuration to ``/etc/opt``, and the data to
      ``/var/opt``). This is what we have been doing with our Django
      project throughout this book.

   This subtle distinction is not always followed in practice by all
   people, so you should be careful with your assumptions.
   
On carefully setup systems, you don't need to backup ``/bin``, ``/lib``,
``/sbin``, ``/usr`` and ``/opt``, because you can recreate them by
re-installing the programs. This is true particularly if you are setting
up your servers using some kind of automation system. I use Ansible. If
a server explodes, I create another one, I press a button, and Ansible
sets up the server in a few minutes, installing and configuring all
necessary software. I only need to restore the data. In theory (and in
practice) I don't need ``/etc`` either, but I never exclude it from
backup, it's only about 10 MB anyway. So, in theory, the only
directories you need to backup are ``/var``, ``/srv``, ``/root`` and
``/home``.

.. warning:: Specify what you want to exclude, not what you want to backup

   If you decide that only a few directories are worth backing up, it
   may be tempting to tell the system "backup directories X, Y and Z"
   instead of telling it "backup the root directory and exclude A, B, C,
   D, E, F, G, H, I and J". Don't do it. In the future, you or another
   administrator will create a directory such as ``/data`` and put
   critical stuff in there, and everyone will forget that it is not
   being backed up. Always backup the root file system and specify what
   you want to exclude, not what you want to include.

If you aren't using automation (and this could fill another book on its
own), it would be better to not exclude ``/opt`` from backup, because it
will make it harder to recover. It's very unlikely ``/bin``, ``/lib``
and ``/sbin`` will be useful when restoring, but they're not much disk
space anyway. The only real question is whether to backup ``/usr``,
which can be perhaps 1 GB. At $0.58 per year it's not much, but it might
also make backup and restore slower.

Is your head spinning? Here's the bottom line: use the exclude list
provided in the previous section, and if you feel confident also exclude
``/bin``, ``/lib``, ``/sbin`` and ``/usr``. If your Django project's
files in ``/opt`` consume much space, and you believe you can re-clone
them fast and setup the virtualenv fast (as described in
:ref:`users_and_directories`), you can also exclude ``/opt``.

**Whatever you decide, you might make an error. You might accidentally
exclude something crucial. This is true even if you don't exclude
anything at all. For example, if you keep encrypted backups, you might
think you are saving everything but you might be forgetting to store the
decryption password somewhere.**

**The only way to be reasonably certain you are not screwing up is to
test your recovery as I explain later.**

.. _check_the_disk_space:

.. tip:: Check the disk space

   Two commands you will find useful are ``df`` and ``du``.

   .. code-block:: bash

      df -h

   This shows the disk space usage for all the file systems. You are
   normally only interested for the file system that is mounted on "/",
   which is something like ``/dev/sda1`` or ``/dev/vda1``. This is your
   main disk.

   .. code-block:: bash

      cd /
      du -sh *

   This will calculate and display the disk space that is occupied by each
   directory. It will throw some error messages, which can be ignored.

   A useful variation is this:

   .. code-block:: bash

      du -sh * | sort -h

   This means "take the standard output of ``du -sh *`` and use it as
   standard input to ``sort -h``". The standard output does not include
   the error messages (these go to the standard error). ``sort`` is a
   program that sorts its input; with the ``-h`` option, it sorts human
   readable byte counts such as "15M" and "1.1G".

   If the output of ``du`` is longer than your terminal, another useful
   idiom is this:

   .. code-block:: bash

      du -sh * | sort -h | less

   This will take the standard output of ``sort`` and give it as input
   to ``less``. ``less`` is a program that only shows only one screenful
   of information at a time. If you get accustomed to it you'll find
   it's much more convenient than using the scrollbar of your terminal.
   You can use j and k (or the arrow keys) to go down and up, space and
   b (or Page Down/Up) for the next and previous screenful, G and g to
   go to the end and beginning, and q to exit. You can also search with
   a slash, and repeat a search forwards and backwards with n and N.

Backing up databases
--------------------

Databases cannot usually be backed up just by copying their data files.
For small databases, copying can take a few seconds or a few minutes.
During this time, the files could be changing. As a result, when you
restore the files, the database might not be internally consistent. Even
if you ensure that no-one is writing to the database, or even that there
are no connections, you can still not copy the files, because the RDBMS
may be caching information and flushing it whenever it likes. To backup
by copying data files you need to shutdown the RDBMS, which means
downtime.

The problem of internal consistency is also present with SQLite. Copying
the database file can take some time, and if the database is being
written to during that time, the file will be internally inconsistent,
that is, corrupt.

Backing up large databases involves complicated strategies, such as
those described in Chapter 25 of the PostgreSQL 9.6 manual. Here we are
going to follow the simplest strategy which is to dump all the database
to a plain text file. Database dumps are guaranteed to be internally
consistent. SQLite may lock the database during the dump, meaning
writing to it will have to wait, but the time you need to wait for small
databases is very little.

For **PostgreSQL**, create file ``/etc/duply/main/pre``, with the
following contents:

.. code-block:: bash

   #!/bin/bash
   su postgres -c 'pg_dumpall --file=/var/backups/postgresql.dump'

For **SQLite**, the contents of ``/etc/duply/main/pre`` should be:

.. code-block:: bash

   #!/bin/bash
   echo '.dump' | \
      sqlite3 /var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db \
          >/var/backups/sqlite-$DJANGO_PROJECT.dump

Better let's make ``/etc/duply/main/pre`` executable:

.. code-block:: bash

   chmod 755 /etc/duply/main/pre

The file is actually a **shell script**. In their simplest form, shell
scripts are just commands one after the other (much like Windows
``.bat`` files). However, Unix shells like bash are complete programming
languages (in fact duply itself is written in bash). We won't do any
complicated shell programming here, but if, for some reason, you have
both PostgreSQL and SQLite on a server, you can join the two above
scripts like this:

.. code-block:: bash

   #!/bin/bash
   su postgres -c 'pg_dumpall --file=/var/backups/postgresql.dump'
   echo '.dump' | \
      sqlite3 /var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db \
          >/var/backups/sqlite-$DJANGO_PROJECT.dump

Likewise, if you have many SQLite databases, you need to add a dump
command for each one in the file (this is not necessary for PostgreSQL,
as ``pg_dumpall`` will dump all databases of the cluster).

Duply will execute ``/etc/duply/main/pre`` before proceeding to copy the
files. (It will also execute ``/etc/duply/main/post``, if it exists,
after copying, but we don't need to do anything like that; with
different backup schemes ``pre`` could, for example, shutdown the
database and ``post`` could start it again.)

If you don't understand the ``pre`` file for SQLite, here is the
explanation: to dump a SQLite database, you connect to it with ``sqlite3
dbname`` and then execute the SQLite ``.dump`` command. The ``sqlite3``
program reads commands from the standard input and writes dumps to the
standard output. The standard input is normally your keyboard; but by
telling it ``echo '.dump' | sqlite3 ...`` we give it the string ".dump",
followed by newline, as standard input (the ``echo`` command just
displays stuff and follows it with a newline; for example, try ``echo
'hello, world'``). The vertical line, as I explained in the previous
section (see :ref:`Check the disk space <check_the_disk_space>`) sends
the output of one command as input to another command. Finally, the ">"
is the **redirection** symbol, it redirects the standard output of the
``sqlite3`` program, which would otherwise be displayed on the terminal,
to a file.

.. tip:: Compressing database dumps

   Database dumps are plain text files. If compressed, they can easily
   become five times smaller. However, compressing them might make
   incremental backups larger and slower. The reason is that in
   incremental backups duplicity saves only what has changed since the
   previous backup. It might be easier for duplicity to detect changes
   in a plain text file than in a compressed file, and the result could
   be to backup the entire compressed file each time.  Since duplicity
   compresses backups anyway, storing the dump file uncompressed will
   never result in larger backups.

   The only downside of storing the dump file uncompressed is that it
   takes up more disk space in the server. This is rarely a problem.

.. tip:: Excluding SQLite

   Technically, since you are dumping the database, you should be
   excluding ``/var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db``, from the
   backup; however if the database file is only a few hundreds of
   kilobytes the savings aren't worth the trouble of adding it to your
   ``exclude`` file.

Running scheduled backups
-------------------------

Create file ``/etc/cron.daily/duply`` with the following contents:

.. code-block:: bash

   #!/bin/bash
   duply main purge --force >/tmp/duply.out
   duply main purgeIncr --force >>/tmp/duply.out
   duply main backup >>/tmp/duply.out

Make the file executable:

.. code-block:: bash

   chmod 755 /etc/cron.daily/duply

In Unix-like systems, cron is the standard scheduler; it executes tasks
at specified times. Scripts in ``/etc/cron.daily`` are executed once
daily, starting at 06:25 (am) local time. The time to which this
actually refers depends on the system's time zone, which you can find by
examining the contents of the file ``/etc/timezone``. In most of my
servers, I use UTC. Backup time doesn't really matter much, but it's
better to do it when the system is not very busy. For time zones with a
positive UTC offset, 06:25 UTC could be a busy time, so you might want
to change the system time zone with this command:

.. code-block:: bash

   dpkg-reconfigure tzdata

There is a way to tell cron exactly at what time you want a task to run,
but I won't go into that as throwing stuff into ``/etc/cron.daily``
should be sufficient for most use cases.

In the ``/etc/cron.daily/duply`` script, the first command, ``purge``,
will delete full backups that are older than ``MAX_AGE``. The second
command, ``purgeIncr``, will delete incremental backups that build on
full backups that are older than ``MAX_FULLS_WITH_INCRS``. Finally, the
third command, ``backup``, will perform an incremental backup, unless a
full backup is due. A full backup is due if you have never backed up in
the past, or if the latest full backup was done more than
``MAX_FULLBKP_AGE`` ago.

Cron expects all the programs it runs to be silent, i.e., to not display
any output. If they do display output, cron emails that output to the
administrator. This is very neat, because if your tasks only display
output when there is an error, you will be emailed only when there is an
error.

Duply, however, displays a lot of information even when everything's
working fine. For this reason, we redirect its output to a file,
``/tmp/duply.out``. We only redirect its standard output, not its
standard error, which means that error (and warning) messages will still
be caught by cron and email. Note, however, that ``/tmp/duply.out`` is
not a complete log file, because it only contains the standard output,
not the standard error. It might have been better to include both output
and error in ``/tmp/duply.out``, and in addtion display the standard
error, so that cron can catch it; however, this requires more advanced
shell scripting techniques and it's more trouble than it's worth.

The redirection for the first command, ``>/tmp/duply.out``, overwrites
``/tmp/duply.out`` if it already exists. The redirection for the next
two commands, ``>>/tmp/duply.out``, appends to the file.

.. warning:: You must use a local mail server

   The emails of cron cannot be sent unless a mail server is installed
   locally on the server. See :ref:`using_a_local_mail_server` to setup
   one. Don't omit it, otherwise you won't know when your system has a
   problem and cannot backup itself.

Chapter summary
---------------

* Keep some offline backups and regularly test recovery (the next
  chapter deals with these).
* Calculate storage costs.
* Create a bucket in your backup storage. A single bucket for all your
  deployments is probably enough. You can name it ``$NICK-backup``.
* Install duply, create directory ``/etc/duply/main``, and chmod it to 700.
* Create configuration file ``/etc/duply/main/conf`` with these
  contents:

  .. code-block:: bash

     GPG_KEY=disabled

     SOURCE=/
     TARGET=b2://$ACC_ID:$APP_KEY@$NICK-backup/$SERVER_NAME/

     MAX_AGE=2Y
     MAX_FULLS_WITH_INCRS=2
     MAX_FULLBKP_AGE=3M
     DUPL_PARAMS="$DUPL_PARAMS --full-if-older-than $MAX_FULLBKP_AGE "

     VERBOSITY=warning
     ARCH_DIR=/var/cache/duplicity/duply_main/

* Create file ``/etc/duply/main/exclude`` with the following contents::

   - /dev
   - /proc
   - /sys
   - /run
   - /var/lock
   - /var/run
   - /lost+found
   - /boot
   - /tmp
   - /var/tmp
   - /media
   - /mnt
   - /var/cache
   - /var/crash
   - /var/swap
   - /var/swapfile
   - /var/swap.img
   - /var/lib/mysql
   - /var/lib/postgresql

  If you feel like it, also exclude ``/bin``, ``/lib``, ``/sbin`` and
  ``/usr``, maybe also ``/opt``.

* Create file ``/etc/duplicity/main/pre`` with contents similar to the
  following (delete the PostgreSQL or SQLite part as needed, or add
  more SQLite commands if you have many SQLite databases):

  .. code-block:: bash

     #!/bin/bash
     su postgres -c 'pg_dumpall --file=/var/backups/postgresql.dump'
     echo '.dump' | \
        sqlite3 /var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db \
            >/var/backups/sqlite-$DJANGO_PROJECT.dump

  Chmod the file to 755.

* Create file ``/etc/cron.daily/duply`` with the following contents:

  .. code-block:: bash

     #!/bin/bash
     duply main purge --force >/tmp/duply.out
     duply main purgeIncr --force >>/tmp/duply.out
     duply main backup >>/tmp/duply.out

  Chmod the file to 755.

* Make sure you have a local mail server installed.
