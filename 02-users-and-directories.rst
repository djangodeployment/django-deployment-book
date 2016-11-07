Users and directories
=====================

Right now your Django project is at ``/root``, or maybe at
``/home/joe``. The first thing we are going to fix is put your Django
project in a proper place.

I will be using ``your_django_project`` as the name of your Django
project.

Creating a user and group
-------------------------

It's a good idea to not run Django as root. I create a user specifically
for that, to which I give the same name as the Django app or project. In
our case, we will use ``your_django_project`` as the name of the user:

.. code-block:: bash

    adduser --system --home=/var/local/lib/your_django_project \
        --no-create-home --disabled-password --group \
        your_django_project

Here is why we use these parameters:

**--system**
    This tells ``adduser`` to create a system user, as opposed to
    creating a normal user. System users are intended to run programs,
    whereas normal users are people. Because of this parameter,
    ``adduser`` will assign a user id less than 1000, which is only a
    convention for knowing that this is a system user. Otherwise there
    isn't much difference. 

**--home=/var/local/lib/your_django_project**
    This specifies the home directory for the user. For system users, it
    doesn't really matter which directory we will choose, but by
    convention we choose the one which holds the program's data. We will
    talk about the ``/var/local/lib/your_django_project`` directory
    later.

**--no-create-home**
    We tell ``adduser`` to not create the home directory. We could allow
    it to create it, but we will create it ourselves later on, for
    instructive purposes.

**--disabled-password**
    The password will be, well, disabled. This means that you won't be
    able to become this user by using a password. However, the root user
    can always become another user (e.g. with ``su``) without using a
    password, so we don't need one.

**--group**
    This tells ``adduser`` to not only add a new user, but to also add a
    new group, having the same name as the user (``your_django_project``
    in our case), and make the new user a member of the new group. We
    will see further below why this is useful.

The program files
-----------------

Your Django project should be structured either like this::

    your_django_project/
    |-- manage.py
    |-- requirements.txt
    |-- your_django_app/
    `-- your_django_project/

or like this::

    your_repository_root/
    |-- requirements.txt
    `-- your_django_project/
        |-- manage.py
        |-- your_django_app/
        `-- your_django_project/

I prefer the former, but some people prefer the extra repository root
directory.

We are going to place your project inside ``/usr/local``. This is the
standard Debian directory for program files that are not installed with
``apt-get``. So, clone or otherwise copy your django project in
``/usr/local/your_django_project`` or in
``/usr/local/your_repository_root``. Do this **as the root user**.
Create the virtualenv for your project **as the root user** as well:

.. code-block:: bash

    virtualenv --system-site-packages --python=/usr/bin/python3 \
        /usr/local/your_django_project-virtualenv

While it might seem strange that we are creating these as the root user
instead of as the ``your_django_project`` user, it is standard practice
for program files to belong to the root user. If you check, you will see
that ``/bin/ls`` belongs to the root user, though you may be running it
as joe. In fact, it would be an error for it to belong to joe, because
then joe would be able to modify it. So for security purposes it's
better for program files to belong to root.

This poses a problem: when the ``your_django_project`` user attempts to
execute your Django application, it will not have permission to write
the compiled Python files in the ``/usr/local/your_django_project``
directory, because this is owned by root. So we need to pre-compile
these files as root:

.. code-block:: bash

    /usr/local/your_django_project-virtualenv/bin/python -m compileall \
        /usr/local/your_django_project

The data directory
------------------

As I already hinted, our data directory is going to be
``/var/local/lib/your_django_project``. This is in line with the Debian
policy where the data for programs other than those installed with
``apt-get`` is stored in ``/var/local/lib``. Most notably, we will store
media files in there (but this in a chapter later). We will also store
the SQLite file in there. Usually in production we use a different
RDBMS, but we will deal with this in a later chapter as well. So, let's
now prepare the data directory:

.. code-block:: bash

    mkdir -p /var/local/lib/your_django_project
    chown your_django_project /var/local/lib/your_django_project

Besides creating the directory, we also changed its owner to the
``your_django_project`` user. This is necessary because Django will be
needing to write data in that directory, and it will be running as that
user, so it needs permission to do so.

The production settings
-----------------------

Debian puts configuration files in ``/etc``, and it is a good idea to
place our configuration there as well:

.. code-block:: bash

    mkdir /etc/your_django_project

For the time being this directory is going to have only ``settings.py``;
later it will have a bit more. Your
``/etc/your_django_project/settings.py`` file should be like this::

    from your_django_project.settings.base import *

    DEBUG = True

    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': '/var/local/lib/your_django_project/your_django_project.db',
        }
    }

I have assumed that your project uses the convention of having, instead
of a single ``settings.py`` file, a ``settings`` directory containing
``__init__.py`` and ``base.py``. ``base.py`` is the base settings, those
that are the same whether in production or development or testing. The
directory often contains ``local.py`` (alternatively named ``dev.py``),
with common development settings, which might or might not be in the
repository. There's often also ``test.py``, settings that are used when
testing. Both ``local.py` and ``test.py`` start with this line::

    from .base import *

Then they go on to override the base settings or add more settings.
When the project is set up like this, ``manage.py`` is usually
modified so that, by default, it uses
``your_django_project.settings.local`` instead of simply
``your_django_project.settings``. For more information on this
technique, see Section 5.2, "Using Multiple Settings Files", in the book
Two Scoops of Django.

Now, people who use this scheme sometimes also have ``production.py`` in
the settings directory of the repository. Call me a perfectionist (with
deadlines), but the production settings are the administrator's job, not
the developer's, and your django project's repository is made by the
developers. You might claim that you are both the developer and the
administrator, since it's you who are deploying the project and
maintaining the deployment, but in this case you are assuming two roles,
wearing a different hat each time.  Production settings don't belong in
the project repository any more than the nginx or PostgreSQL
configuration does.

The proper place to store such settings is another repository, which
contains the "recipe" for setting up a server, with a configuration
management system such as Ansible.  This, however, takes time to learn
and setup, and your deadlines are probably sooner. So you may need to
compromise and store your production settings elsewhere, even in your
project repository. If you do that, then your
``/etc/your_django_project/settings.py`` file shall eventually be a
single line::

    from your_django_project.settings.production import *

However, I don't want you to do this now. We aren't yet going to use our
real production settings, because we are going step by step. Instead,
create the ``/etc/your_django_project/settings.py`` file as I explained
in the beginning of this section.

If you don't use this pattern at all, and you have a single
``settings.py`` file, you should be importing from that one
(``your_django_project.settings``) instead.

Let's now **secure the production settings**. We do not want other users
of the system to be able to read the file, because it contains sensitive
information. Maybe not yet, but after a few chapters it is going to have
the secret key and the password to the database.  At this point, you are
wondering: what other users? I am the only person using this server, and
I have created no users. Indeed, now that it's so easy and cheap to get
small servers and assign a single job to them, this detail is not so
important as it used to be. However, it is still a good idea to harden
things a little bit. Maybe a year later you will create a normal user
account on that server as a little favour for a friend of yours.

If ``your_django_project`` has a vulnerability, an attacker might be
able to give commands to the system as the user as which the project
runs (i.e. as the ``your_django_project`` user). Likewise, in the future
you might install some other web application, and that other web
application might have a vulnerability and could be attacked, and the
attacker might be able to give commands as the user that application
runs. In that case, the attacker wouldn't be able to read our
``settings.py``, because he wouldn't have permission to do so.
Eventually servers get compromised, and we try to set up the system in
such a way to minimize the damage, and we can minimize it if we contain
it, and we can contain it if the compromising of an application does not
result in the compromising of other applications. This is why we want to
run each application in its own user and its own group.

Here is how to harden the permissions of ``settings.py``:

.. code-block:: bash

   chgrp your_django_project /etc/your_django_project/settings.py
   chmod u=rw,g=r,o= /etc/your_django_project/settings.py

What this does is make ``settings.py`` unreadable by users other than
``root`` and user ``your_django_project``. The file is owned by
``root``, and the first command above changes the group of the file so
that it is ``your_django_project``. The second command changes the
permissions of the file so that:

**u=rw**
   The owner has permission to read and write the file (the ``u`` in
   ``u=rw`` stands for "user", but actually it means the "user who owns
   the file"). The owner is ``root``.
**g=r**
   The group has permission to read the file. More precisely, users who
   belong in that group have permission to read the file. The file's
   group is ``your_django_project``. The only user in that group is
   ``your_django_project``, so this adjustment applies only to that
   user.
**o=**
   Other users have no permission, they can't read or write the file.

You might have expected that it would have been easier to tell the
system "I want user ``root`` to be able to read and write, and user
``your_django_project`` to be able to only read". Instead, we did
something much more complicated: we made user ``your_django_project``
belong to a group (with the same name, but this doesn't matter), and we
made the file readable by that group, thus indirectly readable by the
user. The reason we did it this way is an accident of history. In Unix
there has traditionally been no way to say "I want user ``root`` to be
able to read and write, and user ``your_django_project`` to be able to
only read". In many Unixes, including Linux, it is possible using Access
Control Lists, but this is a feature added later, it is not the same in
all Unixes, and its syntax is harder to use. The way we use here works
the same in FreeBSD, HP-UX, and all other Unixes and it is common
practice everywhere.

Finally, we need to **compile** the settings file. Your settings file
and the ``/etc/your_django_project`` directory is owned by root, and, as
with the files in ``/usr/local``, won't be able to write the compile
version, so we pre-compile it as root:

.. code-block:: bash

    /usr/local/your_django_project-virtualenv/bin/python -m compileall \
        /etc/your_django_project
    chgrp -R your_django_project /etc/your_django_project/__pycache__

When Python compiles a ``.py`` file, it gives the ``.pyc`` file the same
mode as the original file, so in our case ``settings.pyc`` will be
readable and writeable by the owner, readable by the group, and
non-accessible by others. However, Python does not set the same owner
and group to the ``.pyc`` file as in the original, which is why we need
to change the group. The above ``chgrp`` command works with Python 3,
and recursively modifies the group of directory
``/etc/your_django_project/__pycache__`` and of the files it contains.
In Python 2, use this instead:

.. code-block:: bash

    chgrp -R your_django_project /etc/your_django_project/settings.pyc

Running the Django server
-------------------------

.. code-block:: bash

    su your_django_project
    source /usr/local/your_django_project-virtualenv/bin/activate
    export PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project
    export DJANGO_SETTINGS_MODULE=settings
    python /usr/local/your_django_project/manage.py migrate
    python /usr/local/your_django_project/manage.py runserver 0.0.0.0:8000

You could also do that in an exceptionally long command (provided you
have already done the ``migrate`` part), like this:

.. code-block:: bash

    PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project \
        DJANGO_SETTINGS_MODULE=settings \
        su your_django_project -c \
        "/usr/local/your_django_project-virtualenv/bin/python \
        /usr/local/your_django_project/manage.py runserver 0.0.0.0:8000"

Do you understand that very clearly? If not, here is some tips:

 * Make sure you have a grip on ``virtualenv``, environment variables,
   and ``su``; all these are explained in the Appendix.
 * Python reads the ``PYTHONPATH`` environment variable and adds
   the specified directories to the Python path.
 * Django reads the ``DJANGO_SETTINGS_MODULE`` environment variable.
   Because we have set it to "settings", Django will attempt to import
   ``settings`` instead of the default (the default is
   ``your_django_project.settings``, or maybe
   ``your_django_project.settings.local``).
 * When Django attempts to import ``settings``, Python looks in its
   path. Because ``/etc/your_djangoproject`` is listed first in
   ``PYTHONPATH``, Python will first look there for ``settings.py``, and
   it will find it there.
 * Likewise, when at some point Django attempts to import
   ``your_django_app``, Python will look in
   ``/etc/your_django_project``; it won't find it there, so then it will
   look in ``/usr/local/your_django_project``, since this is next in
   ``PYTHONPATH``, and it will find it there.
 * If, before running ``manage.py [whatever]``, we had changed directory
   to ``/usr/local/your_django_project``, we wouldn't need to specify
   that directory in ``PYTHONPATH``, because Python always adds the
   current directory to its path. This is why, in development, you just
   tell it ``python manage.py [whatever]`` and it finds your project.
   We prefer, however, to set the ``PYTHONPATH`` and not change
   directory; this way our setup will be clearer and more robust.

If you fire up your browser and visit http://yourowndomain.com:8000/,
you should see your Django project in action. Still wrong of course; we
are still using the Django development server, but we have accomplished
the first step, which was to use an appropriate user and put stuff in
appropriate directories.

Chapter summary
---------------

 * Create a system user and group with the same name as your Django
   project.
 * Put your Django project in ``/usr/local``, with all files owned by
   root.
 * Put your virtualenv in ``/usr/local``, with the directory named like
   your Django project with ``-virtualenv`` appended, with all files
   owned by root.
 * Put your data files in a subdirectory of ``/var/local/lib`` with the
   same name as your Django project, owned by the system user you
   created. If you are using SQLite, the database file will go in there.
 * Put your settings file in a subdirectory of ``/etc`` with the same
   name as your Django project, with all files owned by root. Set
   ``settings.py`` to belong to the system group you created, and to not
   be readable by other users.
 * Precompile the files in ``/usr/local/your_django_project`` and
   ``/etc/your_django_project``. Change the group of the compiled
   configuration files to the system group you created and verify it's
   not readable by other users.
 * Run ``manage.py`` as the system user you created, after specifying
   the environment variables
   ``PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project``
   and ``DJANGO_SETTINGS_MODULE=settings``.
