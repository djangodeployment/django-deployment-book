Recovery part 2
===============

Copying offline
---------------

Restoring a file or directory
-----------------------------

You made some changes to ``/etc/opt/$DJANGO_PROJECT/settings.py`` and
you want it back? No problem:

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

Restoring PostgreSQL
--------------------

How you will restore PostgreSQL depends on what exactly you want to
restore and what the current state of your cluster is. For a moment,
let's assume this:

 1. You have just installed PostgreSQL with ``apt install postgresql``
    and it has created a brand new cluster that only contains the
    databases ``postgres``, ``template0`` and ``template1``.
 2. You want to restore all your databases.

Assuming the dump file is in
``/tmp/restored_files/var/backups/postgresql.dump``, you can do it this
way:

.. code-block:: bash

   cd /tmp/restored_files/var/backups
   su postgres -c 'psql -f postgresql.dump postgres' >/dev/null

The problem is that ``psql`` shows a lot of output, which we don't need.
We redirect the output to ``/dev/null``, which in Unixlike systems is a
black hole; it is a device file that merely discards everything written
to it. We discard only the standard output, not the standard error,
because we want to see error messages. If everything goes well, it
should show you only one error message:

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

Restoring an entire system
--------------------------

Includes recovery plan

Recovery testing
----------------

Recovering from offline backups
-------------------------------

Chapter summary
---------------
