.. _users_and_directories:

Users and directories
=====================

Right now your Django project is at ``/root``, or maybe at
``/home/joe``. The first thing we are going to fix is put your Django
project in a proper place.

I will be using ``$DJANGO_PROJECT`` as the name of your Django
project.

The data directory
------------------

As I already hinted, our data directory is going to be
``/var/opt/$DJANGO_PROJECT``. It is standard policy for programs
installed in ``/opt`` to put their data in ``/var/opt``. Most notably,
we will store media files in there (in a later chapter).  We will also
store the SQLite file there. Usually in production we use a
different RDBMS, but we will deal with this in a later chapter as well.
So, let's now prepare the data directory:

.. code-block:: bash

    mkdir -p /var/opt/$DJANGO_PROJECT
    chown $DJANGO_USER /var/opt/$DJANGO_PROJECT

Besides creating the directory, we also changed its owner to
``$DJANGO_USER``. This is necessary because Django will be needing to
write data in that directory, and it will be running as that user, so it
needs permission to do so.

.. _creating_user:

Creating a user and group
-------------------------

It's a good idea to not run Django as root. We will create a user
specifically for that, and we will give the user the same name as the
Django project, i.e. ``$DJANGO_PROJECT``. However, in principle it can
be different, and I will be using ``$DJANGO_USER`` to denote the user
name, so that you can distinguish when I'm talking about the user and
when about the project.

Execute this command:

.. code-block:: bash

    adduser --system --home=/var/opt/$DJANGO_PROJECT \
        --no-create-home --disabled-password --group \
        --shell=/bin/bash $DJANGO_USER

Here is why we use these parameters:

``--system``
    This tells ``adduser`` to create a system user, as opposed to
    creating a normal user. System users are intended to run programs,
    whereas normal users are people. Because of this parameter,
    ``adduser`` will assign a user id less than 1000, which is only a
    convention for knowing that this is a system user. Otherwise there
    isn't much difference.

``--home=/var/opt/$DJANGO_PROJECT``
    This specifies the home directory for the user. For system users, it
    doesn't really matter which directory we will choose, but by
    convention we choose the one which holds the program's data. We will
    talk about the ``/var/opt/$DJANGO_PROJECT`` directory later.

``--no-create-home``
    We tell ``adduser`` to not create the home directory. We could allow
    it to create it, but we will create it ourselves later on, for
    instructive purposes.

``--disabled-password``
    The password will be, well, disabled. This means that you won't be
    able to become this user by using a password. However, the root user
    can always become another user (e.g. with ``su``) without using a
    password, so we don't need one.

``--group``
    This tells ``adduser`` to not only add a new user, but to also add a
    new group, having the same name as the user, and make the new user a
    member of the new group. We will see further below why this is
    useful. I will be using ``$DJANGO_GROUP`` to denote the new group.
    In principle it could be different than ``$DJANGO_USER`` (but then
    the procedure of creating the user and the group would be slightly
    different), but the most important thing is that I want it to be
    perfectly clear when we are talking about the user and when we are
    talking about the group.

``--shell=/bin/bash``
    By default, ``adduser`` uses ``/bin/false`` as the shell for system
    users, which practically means they are disabled; ``/bin/false``
    can't run any commands. We want the user to have the most common
    shell used in GNU/Linux systems, ``/bin/bash``.

.. _the_program_files:

The program files
-----------------

Your Django project should be structured either like this::

    $DJANGO_PROJECT/
    |-- manage.py
    |-- requirements.txt
    |-- your_django_app/
    `-- $DJANGO_PROJECT/

or like this::

    $REPOSITORY_ROOT/
    |-- requirements.txt
    `-- $DJANGO_PROJECT/
        |-- manage.py
        |-- your_django_app/
        `-- $DJANGO_PROJECT/

I prefer the former, but some people prefer the extra repository root
directory.

We are going to place your project inside ``/opt``. This is a standard
directory for program files that are not part of the operating system.
(The ones that are installed by the operating system go to ``/usr``.)
So, clone or otherwise copy your Django project in
``/opt/$DJANGO_PROJECT`` or in ``/opt/$REPOSITORY_ROOT``. Do
this **as the root user**.  Create the virtualenv for your project **as
the root user** as well:

.. code-block:: bash

    virtualenv --system-site-packages --python=/usr/bin/python3 \
        /opt/$DJANGO_PROJECT/venv
    /opt/$DJANGO_PROJECT/venv/bin/pip install \
        -r /opt/$DJANGO_PROJECT/requirements.txt

While it might seem strange that we are creating these as the root user
instead of as ``$DJANGO_USER``, it is standard practice
for program files to belong to the root user. If you check, you will see
that ``/bin/ls`` belongs to the root user, though you may be running it
as joe. In fact, it would be an error for it to belong to joe, because
then joe would be able to modify it. So for security purposes it's
better for program files to belong to root.

This poses a problem: when ``$DJANGO_USER`` attempts to execute your
Django application, it will not have permission to write
the compiled Python files in the ``/opt/$DJANGO_PROJECT`` directory,
because this is owned by root. So we need to pre-compile
these files as root:

.. code-block:: bash

    /opt/$DJANGO_PROJECT/venv/bin/python -m compileall \
	-x /opt/$DJANGO_PROJECT/venv/ /opt/$DJANGO_PROJECT

The option ``-x /opt/$DJANGO_PROJECT/venv/`` tells compileall to exclude
directory  ``/opt/$DJANGO_PROJECT/venv`` from compilation. This is
because the virtualenv takes care of its own compilation and we should
not interfere.

.. _the_log_directory:

The log directory
-----------------

Later we will setup our Django project to write to log files in
``/var/log/$DJANGO_PROJECT``. Let's prepare the directory.

.. code-block:: bash

    mkdir -p /var/log/$DJANGO_PROJECT
    chown $DJANGO_USER /var/log/$DJANGO_PROJECT

The production settings
-----------------------

Debian puts configuration files in ``/etc``. More specifically, the
configuration for programs that are installed in ``/opt`` is supposed to
go to ``/etc/opt``, which is what we will do:

.. code-block:: bash

    mkdir /etc/opt/$DJANGO_PROJECT

For the time being this directory is going to have only ``settings.py``;
later it will have a bit more. Your
``/etc/opt/$DJANGO_PROJECT/settings.py`` file should be like this:

.. code-block:: Python

    from DJANGO_PROJECT.settings import *

    DEBUG = True
    ALLOWED_HOSTS = ['$DOMAIN', 'www.$DOMAIN']
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': '/var/opt/$DJANGO_PROJECT/$DJANGO_PROJECT.db',
        }
    }

.. note::

   The above is not valid Python until you replace ``$DJANGO_PROJECT``
   with the name of your django project and ``$DOMAIN`` with your
   domain. In all examples until now you might have been able to copy
   and paste the code from the book and use shell variables for
   ``$DJANGO_PROJECT``, ``$DJANGO_USER``, ``$DJANGO_GROUP``, and so on.
   This is, indeed, the reason I chose this notation. However, in some
   places, like in this Python, you have to actually replace it
   yourself. (Occasionally I use DJANGO_PROJECT without the leading
   dollar sign, in order to get the syntax highlighter to work.)

Let's now **secure the production settings**. We don't want other users
of the system to be able to read the file, because it contains sensitive
information. Maybe not yet, but after a few chapters it is going to have
the secret key, the password to the database, the password for the email
server, etc.  At this point, you are wondering: what other users? I am
the only person using this server, and I have created no users. Indeed,
now that it's so easy and cheap to get small servers and assign a single
job to them, this detail is not as important as it used to be. However,
it is still a good idea to harden things a little bit. Maybe a year
later you will create a normal user account on that server as an
unrelated convenience for a colleague.

If your Django project has a vulnerability, an attacker might be able to
give commands to the system as the user as which the project runs (i.e.
as ``$DJANGO_USER``). Likewise, in the future you might install some
other web application, and that other web application might have a
vulnerability and could be attacked, and the attacker might be able to
give commands as the user running that application. In that case, if we
have secured our ``settings.py``, the attacker won't be able to read it.
Eventually servers get compromised, and we try to set up the system in
such a way as to minimize the damage, and we can minimize it if we
contain it, and we can contain it if the compromising of an application
does not result in the compromising of other applications. This is why
we want to run each application in its own user and its own group.

Here is how to make the contents of ``/etc/opt/$DJANGO_PROJECT``
unreadable by other users:

.. code-block:: bash

   chgrp $DJANGO_GROUP /etc/opt/$DJANGO_PROJECT
   chmod u=rwx,g=rx,o= /etc/opt/$DJANGO_PROJECT

What this does is make the directory unreadable by users other than
``root`` and ``$DJANGO_USER``. The directory is owned by ``root``, and
the first command above changes the group of the directory to
``$DJANGO_GROUP``.  The second command changes the permissions of the
directory so that:

**u=rwx**
   The owner has permission to read (rx) and write (w) the directory
   (the ``u`` in ``u=rwx`` stands for "user", but actually it means the
   "user who owns the directory"). The owner is ``root``.  Reading a
   directory is denoted with ``rx`` rather than simply ``r``, where the
   ``x`` stands for "search"; but giving a directory only one of the
   ``r`` and ``x`` permissions is an edge case that I've seen only once
   in my life. For practical purposes, when you want a directory to be
   readable, you must specify both ``r`` and ``x``.  (This applies only
   to directories; for files, the ``x`` is the permission to execute the
   file as a program.)
**g=rx**
   The group has permission to read the directory. More precisely, users
   who belong in that group have permission to read the directory. The
   directory's group is ``$DJANGO_GROUP``. The only user in that group
   is ``$DJANGO_USER``, so this adjustment applies only to that user.
**o=**
   Other users have no permission, they can't read or write to the
   directory.

You might have expected that it would have been easier to tell the
system "I want ``root`` to be able to read and write, and
``$DJANGO_USER`` to be able to only read". Instead, we did something
much more complicated: we made ``$DJANGO_USER`` belong to a
``$DJANGO_GROUP``, and we made the directory readable by that group,
thus indirectly readable by the user. The reason we did it this way is
an accident of history. In Unix there has traditionally been no way to
say "I want ``root`` to be able to read and write, and ``$DJANGO_USER``
to be able to only read". In many modern Unixes, including Linux, it is
possible using Access Control Lists, but this is a feature added later,
it does not work the same in all Unixes, and its syntax is harder to
use. The way we use here works the same in FreeBSD, HP-UX, and all other
Unixes, and it is common practice everywhere.

Finally, we need to **compile** the settings file. Your settings file
and the ``/etc/opt/$DJANGO_PROJECT`` directory is owned by root, and, as
with the files in ``/opt``, Django won't be able to write the
compiled version, so we pre-compile it as root:

.. code-block:: bash

    /opt/$DJANGO_PROJECT/venv/bin/python -m compileall \
        /etc/opt/$DJANGO_PROJECT

Compiled files are the reason we changed the permissions of the
directory and not the permissions of ``settings.py``. When Python writes
the compiled files (which also contain the sensitive information), it
does not give them the permissions we want, which means we'd need to be
chgrping and chmoding each time we compile. By removing read permissions
from the directory, we make sure that none of the files in the directory
is readable; in Unix, in order to read file
``/etc/opt/$DJANGO_PROJECT/settings.py``, you must have permission to
read ``/`` (the root directory), ``/etc``, ``/etc/opt``,
``/etc/opt/$DJANGO_PROJECT``, and
``/etc/opt/$DJANGO_PROJECT/settings.py``.

You can check the permissions of a directory with the ``-d`` option of
``ls``, like this:

.. code-block:: bash

   ls -lhd /
   ls -lhd /etc
   ls -lhd /etc/opt
   ls -lhd /etc/opt/$DJANGO_PROJECT

(In the above commands, if you don't use the ``-d`` option it will show
the contents of the directory instead of the directory itself.)

.. hint:: Unix permissions

   When you list a file or directory with the ``-l`` option of ``ls``,
   it will show you something like ``-rwxr-xr-x`` at the beginning of
   the line. The first character is the file type: ``-`` for a file and
   ``d`` for a directory (there are also some more types, but we won't
   bother with them). The next nine characters are the permissions:
   three for the user, three for the group, three for others.
   ``rwxr-xr-x`` means "the user has permission to read, write and
   search/execute, the group has permission to read and search/execute
   but not write, and so do others".

   ``rwxr-xr-x`` can also be denoted as 755. If you substitute 0 in
   place of a hyphen and 1 in place of r, w and x, you get 111 101 101.
   In octal, this is 755. Instead of

   .. code-block:: bash

      chmod u=rwx,g=rx,o= /etc/opt/$DJANGO_PROJECT

   you can type

   .. code-block:: bash

      chmod 750 /etc/opt/$DJANGO_PROJECT

   which means exactly the same thing. People use this latter version
   much more than the other one, because it is so much easier to type,
   and because converting permissions into octal becomes second nature
   with a little practice.

Managing production vs. development settings
--------------------------------------------

How to manage production vs. development settings seems to be an eternal
question. Many people recommend, instead of a single ``settings.py``
file, a ``settings`` directory containing ``__init__.py`` and
``base.py``. ``base.py`` is the base settings, those that are the same
whether in production or development or testing. The directory often
contains ``local.py`` (alternatively named ``dev.py``), with common
development settings, which might or might not be in the repository.
There's often also ``test.py``, settings that are used when testing.
Both ``local.py`` and ``test.py`` start with this line::

    from .base import *

Then they go on to override the base settings or add more settings.
When the project is set up like this, ``manage.py`` is usually modified
so that, by default, it uses ``$DJANGO_PROJECT.settings.local`` instead
of simply ``$DJANGO_PROJECT.settings``. For more information on this
technique, see Section 5.2, "Using Multiple Settings Files", in the book
Two Scoops of Django; there's also a `stackoverflow answer`_ about it.

.. _stackoverflow answer: http://stackoverflow.com/questions/1626326/how-to-manage-local-vs-production-settings-in-django/15325966#15325966

Now, people who use this scheme sometimes also have ``production.py`` in
the settings directory of the repository. Call me a perfectionist (with
deadlines), but the production settings are the administrator's job, not
the developer's, and your django project's repository is made by the
developers. You might claim that you are both the developer and the
administrator, since it's you who are developing the project and
maintaining the deployment, but in this case you are assuming two roles,
wearing a different hat each time.  Production settings don't belong in
the project repository any more than the nginx or PostgreSQL
configuration does.

The proper place to store such settings is another repository—the
deployment repository. It can be as simple as holding only the
production ``settings.py`` (along with ``README`` and ``.gitignore``),
or as complicated as containing all your nginx, PostgreSQL, etc.,
configuration for several servers, along with the "recipe" for how to
set them up, written with a configuration management system such as
Ansible.

If you choose, however, to keep your production settings in your Django
project repository, then your ``/etc/opt/$DJANGO_PROJECT/settings.py``
file shall eventually be a single line::

    from $DJANGO_PROJECT.settings.production import *

However, I don't want you to do this now. We aren't yet going to use our
real production settings, because we are going step by step. Instead,
create the ``/etc/opt/$DJANGO_PROJECT/settings.py`` file as I explained
in the previous section.

Running the Django server
-------------------------

.. warning::

   We are running Django with ``runserver`` here, which is inappropriate
   for production. We are doing it only temporarily, so that you
   understand several concepts. We will run Django correctly in the
   chapter about :ref:`gunicorn`.

.. code-block:: bash

    su $DJANGO_USER
    source /opt/$DJANGO_PROJECT/venv/bin/activate
    export PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT
    export DJANGO_SETTINGS_MODULE=settings
    python /opt/$DJANGO_PROJECT/manage.py migrate
    python /opt/$DJANGO_PROJECT/manage.py runserver 0.0.0.0:8000

You could also do that in an exceptionally long command (provided you
have already done the ``migrate`` part), like this:

.. code-block:: bash

    PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
        DJANGO_SETTINGS_MODULE=settings \
        su $DJANGO_USER -c \
        "/opt/$DJANGO_PROJECT/venv/bin/python \
        /opt/$DJANGO_PROJECT/manage.py runserver 0.0.0.0:8000"

.. hint:: su

   You have probably heard of ``sudo``, which is a very useful program
   on Unix client machines (desktops and laptops). On the server,
   ``sudo`` is less common and we use ``su`` instead.

   ``su``, like ``sudo``, changes the user that executes a program. If
   you are user joe and you execute ``su -c ls``, then ``ls`` is run as
   root. ``su`` will ask for the root password in order to proceed.

   ``su alice -c ls`` means "execute ``ls`` as user alice". ``su alice``
   means "start a shell as user alice"; you can then type commands as
   user alice, and you can enter ``exit`` to "get out" of ``su``, that
   is, to exit the shell than runs as alice. If you are a normal user
   ``su`` will ask you for alice's password. If you are root, it will
   become alice without questions. This should make clear how the ``su``
   command works when you run the Django server as explained above.

   ``sudo`` works very differently from ``su``. Instead of asking the
   password of the user you want to become, it asks for your password,
   and has a configuration file that describes which user is allowed to
   become what user and with what constraints. It is much more
   versatile. ``su`` does only what I described and nothing more. ``su``
   is guaranteed to exist in all Unix systems, whereas ``sudo`` is an
   add-on that must be installed. By default it is usually installed on
   client machines, but not on servers. ``su`` is much more commonly
   used on servers and shell scripts than ``sudo``.

Do you understand that very clearly? If not, here are some tips:

* Make sure you have a grip on virtualenv_ and `environment
  variables`_.
* Python reads the ``PYTHONPATH`` environment variable and adds
  the specified directories to the Python path.
* Django reads the ``DJANGO_SETTINGS_MODULE`` environment variable.
  Because we have set it to "settings", Django will attempt to import
  ``settings`` instead of the default (the default is
  ``$DJANGO_PROJECT.settings``, or maybe
  ``$DJANGO_PROJECT.settings.local``).
* When Django attempts to import ``settings``, Python looks in its
  path. Because ``/etc/opt/$DJANGO_PROJECT`` is listed first in
  ``PYTHONPATH``, Python will first look there for ``settings.py``, and
  it will find it there.
* Likewise, when at some point Django attempts to import
  ``your_django_app``, Python will look in
  ``/etc/opt/$DJANGO_PROJECT``; it won't find it there, so then it will
  look in ``/opt/$DJANGO_PROJECT``, since this is next in
  ``PYTHONPATH``, and it will find it there.
* If, before running ``manage.py [whatever]``, we had changed directory
  to ``/opt/$DJANGO_PROJECT``, we wouldn't need to specify
  that directory in ``PYTHONPATH``, because Python always adds the
  current directory to its path. This is why, in development, you just
  tell it ``python manage.py [whatever]`` and it finds your project.
  We prefer, however, to set the ``PYTHONPATH`` and not change
  directory; this way our setup will be clearer and more robust.

.. _virtualenv: http://djangodeployment.com/2016/11/01/virtualenv-demystified/
.. _environment variables: http://djangodeployment.com/2016/11/07/what-is-the-difference-between-a-shell-variable-and-an-environment-variable/

Instead of using ``DJANGO_SETTINGS_MODULE``, you can also use the
``--settings`` parameter of ``manage.py``:

.. code-block:: bash

   PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
       su $DJANGO_USER -c \
       "/opt/$DJANGO_PROJECT/venv/bin/python \
       /opt/$DJANGO_PROJECT/manage.py
       runserver --settings=settings 0.0.0.0:8000"

(``manage.py`` also supports a ``--pythonpath`` parameter which could be
used instead of ``PYTHONPATH``, however it seems that ``--settings``
doesn't work correctly together with ``--pythonpath``, at least not in
Django 1.8.)

If you fire up your browser and visit http://$DOMAIN:8000/, you should
see your Django project in action.

Chapter summary
---------------

* Create a system user and group with the same name as your Django
  project.
* Put your Django project in ``/opt``, with all files owned by root.
* Put your virtualenv in ``/opt/$DJANGO_PROJECT/venv``, with all files
  owned by root.
* Put your data files in a subdirectory of ``/var/opt`` with the same
  name as your Django project, owned by the system user you created. If
  you are using SQLite, the database file will go in there.
* Put your settings file in a subdirectory of ``/etc/opt`` with the
  same name as your Django project, whose user is root, whose group is
  the system group you created, that is readable by the group and
  writeable by root, and whose contents belong to root.
* Precompile the files in ``/opt/$DJANGO_PROJECT`` and
  ``/etc/opt/$DJANGO_PROJECT``.
* Run ``manage.py`` as the system user you created, after setting the
  environment variables
  ``PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT`` and
  ``DJANGO_SETTINGS_MODULE=settings``.
