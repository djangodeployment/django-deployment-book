Getting started
===============

Things you need to know
-----------------------

Before continuing, please make sure you have the necessary background:

 * You can develop with **Django** and are familiar with executing stuff
   like ``python manage.py runserver``.
 * You understand **virtualenv** clearly. If you aren't certain about
   this, you may find `my blog post on virtualenv`_ helpful.
 * You can create a **Debian** or **Ubuntu** server, login to it with
   ssh, use scp to copy files, and use some basic commands. If you
   cannot do this, at http://djangodeployment.com/ you will find a free
   email course named "Linux servers 101".
 * You must understand some basic encryption principles, that is, what
   is meant by symmetric and asymmetric or public key encryption. My
   free "Linux servers 101" course also covers this.

Setting up the system locale
----------------------------

The "locale" is the regional settings, among which the character
encoding used.  If the character encoding isn't correctly set to UTF-8,
sooner or later you will run into problems. So checking the system
locale is pretty much the first thing you should do on a new server.

The procedure is this:

 1. Open the file ``/etc/locale.gen`` in an editor and make sure the
    line that begins with "en_US.UTF-8" is uncommented.
 2. Enter the command ``locale-gen``; this will (re)generate the
    locales.
 3. Open the file ``/etc/default/locale`` in an editor, and make sure it
    contains the line ``LANG=en_US.UTF-8``. Changes in this file require
    logout and login to take effect.

Let me now explain what all this is about. The locale consists of a
language, a country, and a character encoding; "en_US.UTF-8" means
English, United States, UTF-8. This tells programs to show messages in
American English; to format items such as dates in the way it's done in
the United States; and to use encoding UTF-8.

Different users can be using different locales. If you have a desktop
computer used by you and your spouse, one could be using English and the
other French. Each user does this by setting the ``LANG`` environment
variable to the desired locale; if not, the default system locale is
used for that user. For servers this feature is less important. While
your Django application may display the user interface in different
languages (and format dates and numbers in different ways), this is done
by Django itself using Django's internationalization and localization
machinery and has nothing to do with what we are discussing here, which
affects mostly the programs you type in the command line, such as
``ls``. Because for servers the feature of users specifying their
preferred locale isn't so important, we usually merely use the default
system locale, which is specified in the file ``/etc/default/locale``.
You can understand English, otherwise you wouldn't be reading this book,
so "en_US.UTF-8" is fine. If you prefer to use another country, such as
"en_UK.UTF-8", it's also fine, but it's no big deal, as I will explain
later on.

Although the system can support a large number of locales, many of these
are turned off in order to save a little disk space. You turn them on by
adding or uncommenting them in file ``/etc/locale.gen``. When you
execute the program ``locale-gen``, it reads ``/etc/locale.gen`` and
determines which locales are activated, and it compiles these locales
from their source files, which are relatively small, to some binary
files that are those actually used by the various programs. We say that
the locales are "generated". If you activate all locales the binary
files will be a little bit over 100 M, so the saving is not that big (it
was important 15 years ago); however they will take quite some time to
generate. Usually we only activate a few.

To check that everything is right, do this:

 1. Enter the command ``locale``; everything (except, possibly,
    ``LANGUAGE`` and ``LC_ALL``) should have the value "en_US.UTF-8".
 2. Enter the command ``perl -e ''``; it should do nothing and give no
    message.

The ``locale`` command merely lists the active locale parameters.
``LC_CTYPE``, ``LC_NUMERIC`` etc. are called "locale categories", and
usually they are all set to the same value. In some edge cases they
might be set to different values; for example, on my laptop I use
"en_US.UTF-8", but especially for ``LC_TIME`` I use "en_DK.UTF-8", which
causes Thunderbird to display dates in ISO 8601. This is not our concern
here and it rarely is on a server. So we don't set any of these
variables, and they all get their value from ``LANG``, which is set by
``/etc/default/locale``.

However, sometimes you might make an error; you might specify a locale
in ``/etc/default/locale``, but you might forget to generate it. In that
case, the ``locale`` command will indicate that the locale is active,
but it will not show that anything is wrong. This is the reason I run
``perl -e ''``.  Perl is a programming language, like Python. The
command ``perl -e ''``, does nothing; it tells Perl to execute an empty
program; same thing as ``python -c ''``. However, if there is anything
wrong with the locale, Perl throws a big warning message; so ``perl -e
''`` is my favourite way of verifying that my locale works. Try, for
example, ``LANG=el_GR.UTF-8 perl -e ''`` to see the warning message.  So
``locale`` shows you which is the active locale, and ``perl -e ''``, if
silent, indicates that the active locale has been generated and is
valid.

I told you a short while ago that the country doesn't matter much for
servers. Neither does the language. What matters is the encoding. You
want to be able to manipulate all characters of all languages. Even if
all your customers are English speaking, there may eventually be some
remark about a Chinese character in a description field. Even if you are
certain there won't, it doesn't make any sense to constrain yourself to
an encoding that can represent only a subset of characters when it's
equally easy to use UTF-8. So you need to make sure you use UTF-8. In
Chapter 8 we will see that installing PostgreSQL is a process
particularly sensitive to the system locale settings.

The programs you run at the command line will be producing output in
your chosen encoding. Your terminal reads the bytes produced by these
programs and must be able to decode them properly, so it must know how
they are encoded. In other words, you must set your terminal to UTF-8 as
well.  Most terminals, including PuTTY and gnome-terminal, are by
default set to UTF-8, but you can change that in their preferences.

Quickly starting Django on a server
-----------------------------------

I want you to understand how Django deployment works, and in order for
you to understand it we'll need to experiment. So you will need an
experimental Debian or Ubuntu server. You could create a virtual machine
on your personal system, but it will be easier and more instructive if
you have a virtual machine on the network. So go to Hetzner, Digital
Ocean, or whatever is your favourite provider, and get a virtual server.
In the rest of this book I will be using $SERVER_IPv4_ADDRESS to denote
the ip address of the server on which your Django project is running; so
you must mentally replace $SERVER_IPv4_ADDRESS with "1.2.3.4" or
whatever the address of your server is. Likewise with
$SERVER_IPv6_ADDRESS, if your server has one.

Experimenting means we will be trying things. We will be installing your
Django project and do things with it, and then we will be deleting it
and reinstalling it to try things differently as we move on. You must
have mastered setting up a development server from scratch. You should
be able to setup your Django project on a newly installed machine within
a couple of minutes at most, with a sequence of commands similar to the
following:

.. code-block:: bash

   apt install git python3 virtualenvwrapper
   git clone $DJANGO_PROJECT_REPOSITORY
   cd $DJANGO_PROJECT
   mkvirtualenv --system-site-packages $DJANGO_PROJECT
   pip install -r requirements.txt
   python3 manage.py migrate
   python3 manage.py runserver

It doesn't matter if you use Python 2 instead of 3, or ``mercurial`` (or
even, horrors, FTP) instead of ``git``, or plain ``virtualenv`` instead
of virtualenvwrapper, or if you don't use ``--system-site-packages``.
What *is* important is that you have a grip on a sequence of commands
similar to the above and get your development server running in one
minute. We will be using ``virtualenv`` heavily; if you aren't
comfortable with ``virtualenv``, read `my blog post on virtualenv`_.

So, you have your virtual server, and you have a sequence of commands
that can install a Django development server for your project.  Go ahead
and do so on the virtual server. Do it as the root user, in the
``/root`` directory.

Now, make sure you have this in your settings::

   DEBUG = True
   ALLOWED_HOSTS = ['$SERVER_IPv4_ADDRESS']

Then, instead of running the development server with
``./manage.py runserver`` run it as follows:

.. code-block:: bash

    ./manage.py runserver 0.0.0.0:8000

After it starts, go to your web browser and tell it to go to
http://$SERVER_IPv4_ADDRESS:8000/. You should see your Django project in
action.

Usually you run the Django development server with ``./manage.py
runserver``, which is short for ``./manage.py runserver 8000``. This
tells the Django development server to listen for connections on port
8000. However, if you just specify "8000", it only listens for local
connections; a web browser running on the server machine itself will be
able to access the Django development server at
"http://localhost:8000/", but remote connections, from another machine,
won't work. We use "0.0.0.0:8000" instead, which asks the Django
development server to listen for remote network connections. Even
better, if your virtual server has IPv6 enabled, you can use this:

.. code-block:: bash

    ./manage.py runserver [::]:8000

This will cause Django to listen for remote connections on port 8000,
both for IPv4 and IPv6.

Next problem is that you can't possibly ask your users to use
http://$SERVER_IPv4_ADDRESS:8000/. You have to use a domain name, and,
you have to get rid of the ":8000" part. Let's deal with the ":8000"
first.  "http://$SERVER_IPv4_ADDRESS/" is actually a synonym for
"http://$SERVER_IPv4_ADDRESS:80/", so we need to tell Django to listen
on port 80 instead of 8000. This may or may not work:

.. code-block:: bash

    ./manage.py runserver 0.0.0.0:80

Port 80 is privileged. This means that normal users aren't allowed to
listen for connections on port 80; only the root user is. So if you run
the above command as as a normal user, Django will probably tell you
that you don't have permission to access that port.  If you run the
above command as root, it should work.  If it tells you that the port is
already in use, it probably means that a web server such as Apache or
nginx is already running on the machine. Shut it down:

.. code-block:: bash

    service apache2 stop
    service nginx stop

When you finally get ``./manage.py runserver 0.0.0.0:80`` running, you
should, at last, be able to go to your web browser and reach your Django
project via http://$SERVER_IPv4_ADDRESS/. Congratulations!

Things we need to fix
---------------------

Now, of course, this is the wrong way to do it. It's wrong for the
following reasons:

 * The URL http://$SERVER_IPv4_ADDRESS/ is ugly; you need to use a
   domain name.
 * You have put your project in ``/root``.
 * You are running Django as root.
 * You have Django serve your static files, and you have DEBUG=True.
 * You are using ``runserver``, which is seriously suboptimal and only
   meant for development.
 * You are using SQLite.

Let's go fix them.

.. _my blog post on virtualenv: http://djangodeployment.com/2016/11/01/virtualenv-demystified/

