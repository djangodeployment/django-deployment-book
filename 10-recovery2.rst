Recovery part 2
===============

Restoring a file or directory
-----------------------------

You made some changes to ``/etc/opt/$DJANGO_PROJECT/settings.py``,
changed your mind, and you want it back? No problem:

.. code-block:: bash

   duply main fetch etc/opt/$DJANGO_PROJECT/settings.py \
      /tmp/restored_settings.py

This will fetch the most recent version of the file from backup and will
put it in ``/tmp/restored_settings.py``. Note that when you specify the
source file there is no leading slash.

You can also fetch previous versions of the file:

.. code-block:: bash

   # Fetch it as it was 4 days ago
   duply main fetch etc/opt/$DJANGO_PROJECT/settings.py \
      /tmp/restored_settings.py 4D

   # Fetch it as it was on 4 January 2017
   duply main fetch etc/opt/$DJANGO_PROJECT/settings.py \
      /tmp/restored_settings.py 2017-01-04

Here is how to restore all the backup into ``/tmp/restored_files``:

.. code-block:: bash

   duply main restore /tmp/restored_files

As before, you can append age specifiers such as ``4D`` or
``2017-01-04`` to the command. Note that restoring a large backup can
incur charges by your backup storage provider.

You should probably never restore files directly to their original
location. Instead, restore into ``/tmp`` or ``/var/tmp`` and move 
or copy them.

.. _restoring_sqlite:

Restoring SQLite
----------------

Restoring SQLite is very simple. Assuming the dump file is in
``/tmp/restored_files/var/backups/sqlite-$DJANGO_PROJECT.dump``, you
should be able to recreate your database file thus:

.. code-block:: bash

   sqlite3 /tmp/$DJANGO_PROJECT.db \
       </tmp/restored_files/var/backups/sqlite-$DJANGO_PROJECT.dump

This will create ``/tmp/$DJANGO_PROJECT.db`` and it will execute the
commands in the dump file. You can then move the file to its normal
position, such as ``/var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db``. You
probably need to ``chown`` it to $DJANGO_USER.

.. _restoring_postgresql:

Restoring PostgreSQL
--------------------

How you will restore PostgreSQL depends on what exactly you want to
restore and what the current state of your cluster is. For a moment,
let's assume this:

 1. You have just installed PostgreSQL with ``apt install postgresql``
    and it has created a brand new cluster that only contains the
    databases ``postgres``, ``template0`` and ``template1``.
 2. You want to restore all your databases.

Assuming ``/tmp/restored_files/var/backups/postgresql.dump`` is the dump
file, you can do it this way:

.. code-block:: bash

   cd /tmp/restored_files/var/backups
   su postgres -c 'psql -f postgresql.dump postgres' >/dev/null

``psql`` shows a lot of output, which we don't need.  We redirect the
output to ``/dev/null``, which in Unix-like systems is a black hole; it
is a device file that merely discards everything written to it. We
discard only the standard output, not the standard error, because we
want to see error messages. If everything goes well, it should show only
one error message:

    ERROR:  role "postgres" already exists

The file written to by ``pg_dumpall`` contains SQL commands that can be
used to recreate all databases. In the beginning of the file there are
commands that first create the users. One of these users is
``postgres``, but this already exists in your new cluster, therefore the
error message.  (The dump file also includes commands to create the
databases, but ``pg_dumpall`` is smart enough to not include database
creation commands for template0, template1, and postgres.)

.. hint:: Playing with redirections

   You might want to redirect the standard error as well as the standard
   output. You can do it like this:

   .. code-block:: bash

      su postgres -c 'psql -f postgresql.dump postgres' \
         >/tmp/psql.out 2>/tmp/psql.err

   This actually means "redirect file descriptor 1 to /tmp/psql.out and
   file descriptor 2 to /tmp/psql.err". Instead of ``>file`` you can
   write ``1>file``, but 1 is the default and custom has it to omit it
   almost always. File descriptor 1 is always standard output, and 2 is
   always standard error. There are several use cases for redirecting
   the standard error, and one of them is if you want to keep a record
   of the error messages so that you can examine them later.

   One problem is that ``psql`` actually throws error messages
   interspersed with standard output messages, and if you separate
   output from error you might not know at which stage the error
   occurred. If you want to log the error messages in the same file and
   in the correct position in relation to the output messages, you can
   do this:

   .. code-block:: bash

      su postgres -c 'psql -f postgresql.dump postgres' \
         >/tmp/psql.out 2>&1
   
   The ``2 > &1`` means "redirect the standard error to the same place
   where you're putting the standard output".

   However, this will not always work as you expect because the standard
   output is buffered whereas the standard error is unbuffered; so
   sometimes error messages can appear in the file **before** output
   that was supposed to be printed before the error.

If something goes wrong and you want to start over, here is how, but
**be careful not to type these in the wrong window** (you could delete a
production cluster in another server):

.. code-block:: bash

   service postgresql stop
   pg_dropcluster 9.5 main
   pg_createcluster 9.5 main
   service postgresql start

The second command will remove the "main" cluster of PostgreSQL version
9.5 (replace that with your actual PostgreSQL version). The third
command will initialize a brand new cluster.

.. _restoring_an_entire_system:

Restoring an entire system
--------------------------

A few sections ago we saw how to restore all backed up files in a
temporary directory such as ``/tmp/restored_files``. If your server (the
"backed up server") has exploded, you might be tempted to setup a new
server (the "restored server") and then just restore all the backup
directly in the root directory instead of a temporary directory. This
won't work correctly, however. For example, if you restore all of
``/var/lib``, you will overwrite ``/var/lib/apt`` and ``/var/lib/dpkg``,
where the system keeps track of what packages it has installed, so it
will think it has installed all the packages that had been installed in
the backed up server, and the system will essentially be broken. Or if
you restore ``/etc/network`` you might overwrite the restored system's
network configuration with the network configuration of the backed up
server. So you can't do this; you need restore the backup in
``/tmp/restored_files`` and then selectively move or copy stuff from
there to its normal place.

Below I present a complete recovery plan that you can use whenever your
system needs recovery. It should be applicable in its entirety only when
you need a complete recovery; however, if you need a partial recovery
you can still follow it and omit some parts as you go. **I assume the
backed up system only had Django apps deployed in the way I have
described in the rest of this book.** If you have something else
installed, or if you have deployed in a different way (e.g. in different
directories), you **must** modify the plan with one of your own.

You must also make sure that you have access to the recovery plan even
if the server goes down; that is, don't store the recovery plan on a
server that is among those that may need to be recovered.

 1. Notify management, or the customer, or whoever is affected and needs
    to be informed.

 2. Take notes. In particular, mark on this recovery plan anything that
    needs improvement.

 3. Create a new server and add your ssh key.

 4. Change the DNS so that $DOMAIN, www.$DOMAIN, and any other needed
    name points to the IP address of the new server (see
    :ref:`adding_dns_records`).

 5. Create a user and group for your Django project (see
    :ref:`creating_user`).

 6. Install packages:

    .. code-block:: bash
    
       apt install python python3 \
          python-virtualenv python3-virtualenv \
          postgresql python-psycopg2 python3-psycopg2 \
          sqlite3 dma nginx-light duply

    (Ignore questions on how to setup dma, we will restore its
    configuration from the backup later.)

    If you use Apache, install ``apache2`` instead of ``nginx-light``.
    The actual list of packages you need might be different (but you
    can also find this out while restoring).

 7. Check duplicity version with ``duplicity --version``; if earlier
    than 0.7.6 and your backups are in Backblaze B2, install a more
    recent version of duplicity as explained in
    :ref:`Installing duplicity in Debian
    <installing_duplicity_in_debian>`.

 8. Create the duply configuration directory and file as explained in
    :ref:`setting_up_duplicity_and_duply` (you don't need to create any
    files beside ``conf``, you don't need ``exclude`` or ``pre``).

 9. Restore the backup in ``/var/tmp/restored_files``:
    
    .. code-block:: bash

       duply main restore /var/tmp/restored_files

10. Restore the ``/opt``, ``/var/opt`` and ``/etc/opt`` directories:

    .. code-block:: bash

       cd /var/tmp/restored_files
       cp -a var/opt/* /var/opt/
       cp -a etc/opt/* /etc/opt/
       cp -a opt/* /opt/

    (If you have excluded ``/opt`` from backup, clone/copy your Django
    project in ``/opt`` and create the virtualenv as described in
    :ref:`the_program_files`.)
 
 11. Create the log directory as explained in :ref:`the_log_directory`.

 12. Restore your nginx configuration:

     .. code-block:: bash

        service nginx stop
        rm -r /etc/nginx
        cp -a /var/tmp/restored_files/etc/nginx /etc
        service nginx start

     If you use Apache, restore your Apache configuration instead:

     .. code-block:: bash

        service apache2 stop
        rm -r /etc/apache2
        cp -a /var/tmp/restored_files/etc/apache2 /etc/
        service apache2 start

 13. Create your static files directory and run ``collectstatic`` as
     explained in Chapter "Static and media files", in
     :ref:`setting_up_django`.

 14. Restore the systemd service file for your Django project and enable
     the service:

     .. code-block:: bash

        cd /var/tmp/restored_files
        cp etc/systemd/system/$DJANGO_PROJECT.service \
            /etc/systemd/system/
        systemctl enable $DJANGO_PROJECT

 15. Restore the configuration for the DragonFly Mail Agent:

     .. code-block:: bash

        rm -r /etc/dma
        cp -a /var/tmp/restored_files/etc/dma /etc/

 16. Create the cache directory as described in :ref:`caching`.

 17. Restore the databases as explained in :ref:`restoring_sqlite` and
     :ref:`restoring_postgresql`.

 18. Restore the duply configuration:

     .. code-block:: bash

        rm -r /etc/duply
        cp -a /var/tmp/restored/files/etc/duply /etc/

 19. Restore the ``duply`` cron job:

     .. code-block:: bash

        cp /var/tmp/restored/etc/cron.daily/duply /etc/cron.daily/

     (You may want to list ``/var/tmp/restored/etc/cron.daily`` and
     ``/etc/cron.daily`` to see if there is any other cronjob that needs
     restoring.)

 20. Start the Django project and verify it works:

     .. code-block:: bash

        service $DJANGO_PROJECT start

 21. Restart the system and verify it works:

     .. code-block:: bash

        shutdown -r now

The system might work perfectly without restart; the reason we restart
it is to verify that if the server restarts, all services will startup
properly.

After you've finished, update your recovery plan with the notes you
took.

Recovery testing
----------------

In the previous chapter I said several times that you must test your
recovery. Your recovery testing plan depends on the extent to which
downtime is an issue.

If downtime is not an issue, that is, you can find a date and time in
which the system is not being used, the simplest way to test the
recovery is to shutdown the server, pretend it has been entirely
deleted, and follow the recovery plan in the previous section to bring
the system up on a new server. Keep the old server off for a week or a
month or until you feel confident it really has no useful information,
then delete it.

If you can't have much downtime, maybe there are times when the system
is not being written to. Many web apps are like this; you want them to
always be readable by the visitors, but maybe they are not being updated
off hours. In that case, notify management or the customer about what
you are going to do, pick up an appropriate time, and test the recovery
with the following procedure:

 1. In the DNS, verify that the TTL of $DOMAIN, www.$DOMAIN, and any
    other necessary record is no more than 300 seconds or 5 minutes (see
    :ref:`adding_dns_records`).

 2. Follow the recovery plan of the previous section to bring up the
    system on a new server, **but omit the step about changing the
    DNS**. (Hint: you can :ref:`edit your own hosts file
    <editing_the_hosts_file>` while checking if the new system works.)

 3. After the system works and you've fixed all problems, change the DNS
    so that $DOMAIN, www.$DOMAIN, and any other needed name points to
    the IP address of the new server (see :ref:`adding_dns_records`).

 4. Wait for five minutes, then shut down the old server.

You could have zero downtime by only following the first two steps
instead of all four, and after you are satisfied discard the *new*
server instead of the old one. However, you can't really be certain you
haven't left something out if you don't use the new server
operationally. So while following half the testing plan can be a good
idea as a preliminary test in order to get an idea of how much time will
be needed by the actual test, staying there and not doing the actual
test is a bad idea.

If you think you can't afford any downtime at all, you are doing
something wrong. You *will* have downtime when you accidentally delete a
database, when there is a hardware or network error, and in many other
cases. Pretending you won't is a bad idea. If you really can't afford
downtime, you should setup high availability (which is a lot of work and
can fill in several books by itself). If you don't, it means that the
business *can* afford a little downtime once in a while, so having a
little scheduled downtime once a year shouldn't be a big deal.

In fact, I think that, in theory at least, recovery should be tested
during business hours, possibly without notifying the business in
advance (except to get permission to do it, but not to arrange a
specific time). Recovery isn't merely a system administrator's issue,
and an additional recovery plan for management might need to be
created, that describes how the business will handle the situation (what
to tell the customers, what the employees should do, and so on).
Recovery with downtime during business hours can be a good exercise for
the whole business, not just for the administrator.

Copying offline
---------------

Briefly, here is how to copy the server's data to your local machine:

.. code-block:: bash

   awk '{ print $2 }' /etc/duply/main/exclude >/tmp/exclude
   tar czf - --exclude-from=/tmp/exclude / | \
       split --bytes=200M - \
           /tmp/`hostname`-`date --iso-8601`.tar.gz.

This will need some explanation, of course, but it will create one or more
files with filenames similar to the following:

| ``/tmp/myserver-2017-01-22.tar.gz.aa``
| ``/tmp/myserver-2017-01-22.tar.gz.ab``
| ``/tmp/myserver-2017-01-22.tar.gz.ac``

We will talk about downloading them later on. Now let's examine what we
did. We will check the last command (i.e. the ``tar`` and ``split``)
first.

We've seen the ``tar`` command earlier, in :ref:`Installing duplicity in
Debian <installing_duplicity_in_debian>`. The "c" in "czf" means we will
create an archive; the "z" means the archive will be compressed; the "f"
followed by a file name specifies the name of the archive; "f" followed
by a hyphen means the archive will be created in the standard output.
The last argument to the ``tar`` command specifies which directory
should be put in the archive; in our case it's a mere slash, which means
the root directory. The ``--exclude-from=/tmp/exclude`` option means
that files and directories specified in the ``/tmp/exclude`` file should
not be included in the archive.

This would create an archive with all the files we need, but it might be
too large. If your external disk is formatted in FAT32, it might not be
able to hold files larger than 2 GB. So we take the data thrown at the
standard output and we split it in manageable chunks of 200 MB each.
This is what the ``split`` command does. The hyphen in ``split`` means
"split the standard input". The last argument to ``split`` is the file
prefix; the files ``split`` creates are named ``PREFIXaa``,
``PREFIXab``, and so on.

The backticks in the specified prefix are a neat shell trick: the shell
executes the command within the backticks, takes the command's standard
output, and inserts it in the command line. So the shell will first
execute ``hostname`` and ``date --iso-8601``, it will then create the
command line for ``split`` that contains among other things the output
of these commands, and then it will execute ``split`` giving it the
calculated command line. We have chosen a prefix that ends in
``.tar.gz``, because that is what compressed tar files end in. If you
concatenate these files into a single file ending in ``.tar.gz``, that
will be the compressed tar file. We will see how to concatenate them two
sections ahead.

Finally, let's explain the first command, which creates
``/tmp/exclude``.  We want to exclude the same directories as those
specified in ``/etc/duply/main/exclude``. However, the syntax used by
duplicity is different from the syntax used by ``tar``. Duplicity needs
the pathnames to be preceded by a minus sign and a space, whereas
``tar`` just wants them listed. So the first command merely strips the
minus sign. ``awk`` is actually a whole programming language, but you
don't need to learn it (I don't know it either). The ``{ print $2 }``
means "print the second item of each line".  While ``awk`` is the
canonical way of doing this in Unix-like systems, you could do it with
Python if you prefer, but it's much harder:

.. code-block:: bash

   python -c "import sys;\
       print('\n'.join([x.split()[1] for x in sys.stdin]))" \
       </etc/duply/main/exclude >/tmp/exclude

Now let's **download the archive**. That's easy using ``scp`` (on
Unix-like systems) or ``pscp`` (on Windows). Assuming the external disk
is plugged in and available as $EXTERNAL_DISK (i.e. something like
``/media/user/DISK`` on GNU/Linux, and something like ``E:\`` on
Windows), you can put it directly in there like this:

.. code-block:: bash

   scp root@$SERVER_IP_ADDRESS:/tmp/*.tar.gz.* $EXTERNAL_DISK

In Windows, use ``pscp`` instead of ``scp``. You can also use graphical
tools, however command-line tools can often be more convenient.

In Unix-like systems, a better command is ``rsync``:

.. code-block:: bash

   rsync root@$SERVER_IP_ADDRESS:/tmp/*.tar.gz.* $EXTERNAL_DISK

If for some reason the transfer is interrupted and you restart it,
``rsync`` will only transfer the parts of the files that have not yet
been transferred. ``rsync`` must be installed both on the server and
locally for this to work. You may have success with Windows rsync
programs such as DeltaCopy.

One problem with the above scheme is that we temporarily store the split
tar file on the server, and the server might not have enough disk space
for that. In that case, if you run a Unix-like system locally, this
might work:

.. code-block:: bash

   ssh root@$SERVER_IP_ADDRESS \
       "awk '{ print \$2 }' /etc/duply/main/exclude
           >/tmp/exclude; \
        tar czf - --exclude-from=/tmp/exclude  /" | \
     split --bytes=200M - \
        $EXTERNAL_DISK/$SERVER_NAME-`date --iso-8601`.tar.gz.

The ``ssh`` command will login to the remote server and execute the
commands ``awk`` and ``tar``, and it will capture their standard output
(i.e. ``tar``'s standard output, because ``awk``'s is redirected) and it
will throw it in its own standard output.

The trickiest part of this ``ssh`` command is that, in the ``awk``, we
have escaped the dollar sign with a backslash. ``awk`` is a programming
language, and ``{ print $2 }`` is an ``awk`` program. ``awk`` must
literally receive the string ``{ print $2 }`` as its program. When we
give a local shell the command ``awk '{ print $2 }'``, the shell leaves
the ``{ print $2 }`` as it is, because it is enclosed in single quotes.
If, instead, we used double quotes, we would use ``awk "{ print \$2
}"``, otherwise, if we simply used ``$2``, the shell would try to expand
it to whatever ``$2`` means (see :ref:`Bash syntax <syntax_is_bash>`).
Now the string given to ``ssh`` is a double-quoted string. The *local*
shell gets that string and performs expansions and runs ``ssh`` after it
has done these expansions; and ``ssh`` gets the resulting string,
executes a shell remotely, and gives it that string. You can understand
the rest of the story with a bit of thinking.

If you aren't running a Unix-like system locally, something else you can
do is use another Debian/Ubuntu server that you have on the network and
does have the disk space. You can also temporarily create one at Digital
Ocean just for the job. After running the above command to create the
backup and store it in the temporary server, you can then copy it to
your local machine and external disk.

You may have noticed we did not backup the databases. I assume that your
normal backup script does this every day, and it stores the saved
databases in ``/var/backups``. You need to be careful, however, to not
run the ``tar`` command at the same time cron and duply run
``/etc/duply/main/pre``, otherwise you might be copying them at exactly
the time they are being overwritten.

Storing and rotating external disks
-----------------------------------

In the previous chapter I told you you need two external disks. Store
one of them at your office and the other elsewhere—at your home, at your
boss's home, at a bank vault, at a backup storage company, or at your
customer's office or home (however don't give your customer a disk that
also contains data of other customers of yours). Whatever place you
chose, I will be calling it "off site". So you will be keeping one disk
off site and one on site. Whenever you want to perform an offline backup
(say once per month), connect the disk you have on site, delete all the
files it contains, and perform the procedure described in the previous
section to backup your servers on it. After that, physically label it
with the date (overwriting or removing the previous label), and move it
off site. Bring the other disk on site and let it sit there until the
next offline backup.

Why do we use two disks instead of just one? Well, it's quite
conceivable that your online data (and online backup) will be severely
damaged, and you can perform an offline backup, wiping out the previous
one, before realizing the server's severely damanged. In that case, your
offline disk will contain damaged data. Or the attacker might wait for
you to plug in the backup disk, and then wipe it out and proceed to wipe
out the online backup and your servers.

You might object that there is a weakness to this plan because the two
disks are at the same location, off site, when you take there the
recently used disk and exchange it with the older one. I wouldn't worry
too much about this. Offline backups are extra backups anyway, and you
hope to never need to use them. While it's possible that someone can get
access to all your passwords and delete all your online servers and
backups, the probability of this happening at the same time as the
physical destruction of your two offline disks at the limited time they
are both off site is so low that you should probably worry more about
your plane crashing.

With this scheme, you might lose up to one month of data. Normally this
is too much, but maybe for the extreme case we are talking about it's
OK. Only you can judge that. If you think it's unacceptable, you might
perform offline backups more often. If you do them more often than once
every two weeks, it would be better to use more external disks.

Recovering from offline backups
-------------------------------

You will probably never need to recover from offline backups, so we
won't go into much detail. If a disaster happens and you need to restore
from offline, the most important thing you need to care about is the
safety of your external disk. Make **absolutely certain** you will only
plug it on a safe computer, one that is certainly not compromised by any
attacker. Do this very slowly and think about every step. After plugging
the external disk in, copy its files to the computer's disk, then unplug
the external disk immediately and keep it safe.

Recovery is the same as what's described in
:ref:`restoring_an_entire_system`, except for the steps that use duply
and duplicity to restore the backup in ``/var/tmp/restored_files``.
Instead, copy the ``.tar.gz.XX`` files to the server's ``/var/tmp``
directory; use ``scp`` or ``pscp`` or ``rsync`` for that (``rsync`` is
the best if you have it).  When you have them all, join them in one
piece with the concatenation command, ``cat``, then untar them:

.. code-block:: bash

   cd /tmp
   cat *.tar.gz.* >backup.tar.gz
   mkdir restored_files
   cd restored_files
   tar xf ../backup.tar.gz

If you are low on disk space, you might join the concatenation command
with the tar command, like this:

.. code-block:: bash

   cd /tmp
   mkdir restored_files
   cd restored_files
   cat ../*.tar.gz.* | tar xf -

Scheduling manual operations
----------------------------

In the previous chapter, I described stuff that you will eventually
setup in such a way that it runs alone. Your servers will be backing up
themselves without your knowing anything about it.  In contrast, all the
procedures I described in this chapter are to be manually executed by a
human:

 * Restoring part of a system or the whole system
 * Recovery testing
 * Copying offline
 * Recovering from offline backups

Some of these procedures will be triggered by an event, such as losing
data. Recovery testing, however, and copying offline, will not be
triggered; *you* must take care that they occur. This can be as simple
as adding a few recurring entries to your calendar, or as hard as
inventing foolproof procedures to be added to the company's operations
manual. Whatever you do, you must make sure it works. **If you don't
test recovery, it is almost certain it will take too long when you need
it, and it is quite likely you will be unable to recover at all.**

Chapter summary
---------------

 * Use the provided recovery plan or devise your own.
 * Make sure you will have access to the recovery plan (and all required
   information such as logins and passwords) even if your server stops
   existing.
 * Test your recovery plan once a year or so.
 * Backup online as well as to offline disks and store them safely.
 * Don't backup to offline disks at the same time as the system is
   performing its online backup.
 * Create an offline backup schedule and a recovery testing schedule and
   make sure they are being followed.
