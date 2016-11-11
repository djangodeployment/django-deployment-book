Getting started
===============

Things you need to know
-----------------------

TODO: Fix this

Before continuing, please make sure you have the necessary background:

 * You can develop with **Django** and are familiar with executing stuff
   like ``python manage.py runserver``.
 * You understand **virtualenv**.
 * You can create a **Debian** or **Ubuntu** server, login to it with
   ssh, use scp to copy files, and use some basic commands, including
   ``sudo`` and ``apt-get update/upgrade/install/remove``.
 * You can use **DNS** to point your domain name to your server.
 * You have chosen between **Apache** and **nginx**.

With the exception of being able to develop with Django, you can get an
introduction to the rest at the Appendix.

Quickly starting Django on a server
-----------------------------------

I want you to understand how Django deployment works, and in order for
you to understand it we'll need to experiment. So you will need a Debian
or Ubuntu server on which to experiment. You could create a virtual
machine on your personal system, but it will be easier and more
instructive if you have a virtual machine on the network, and a domain
name that points to it. So go to Hetzner, Digital Ocean, or whatever is
your favourite provider, and get a virtual server. Also get a domain
name and set it to point to the virtual server. In the rest of this book
I will be using $DOMAIN to denote the domain under which your Django
project is running; so you must mentally replace $DOMAIN with
"mydomain.com" or whatever your domain is.

Experimenting means we will be trying things. We will be installing your
Django project and do things with it, and then we will be deleting it
and reinstalling it to try things differently as we move on. You must
have mastered setting up a development server from scratch. You should
be able to setup your Django project on a newly installed machine within
a couple of minutes at most, with a sequence of commands similar to the
following:

.. code-block:: bash

   apt-get install git python3 virtualenvwrapper
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
comfortable with ``virtualenv``, I have a good introduction for you at
the Appendix; go read it now.

So, you have your virtual server, and you have a sequence of commands
that can install a Django development server for your project.  Go ahead
and do so on the virtual server. You don't need to be the root user to
do so, better do it as a normal user, exactly as if you were going to do
development; but if you only have a root user on the virtual server, no
worry, use the root user, and do your job in the file:`/root` directory.

Now, make sure ``DEBUG=True``, and that you have your $DOMAIN in
``ALLOWED_HOSTS``, and instead of running the development server with
``./manage.py runserver`` run it as follows:

.. code-block:: bash

    ./manage.py runserver 0.0.0.0:8000

After it starts, go to your web browser and tell it to go to
http://$DOMAIN:8000/. You should see your Django project
in action.

Usually you run the Django development server with ``./manage.py
runserver``, which is short for ``./manage.py runserver 8000``. This
tells the Django development server to listen for connections on port
8000. However, if you just specify "8000", it only listens for local
connections; a web browser running on the server machine itself will be
able to access the Django development server at
"http://localhost:8000/", but remote connections, from another machine,
won't work. We use "0.0.0.0:8000" instead, which asks the Django
development server to listen for network connections. Even better, if
your virtual server has IPv6 enabled, you can use this:

.. code-block:: bash

    ./manage.py runserver [::]:8000

This will cause Django to listen for connections on port 8000, both for
IPv4 and IPv6.

Next problem is that you can't possibly ask your users to use
http://$DOMAIN:8000/, you have to get rid of the ":8000"
part. "http://$DOMAIN/" is actually a synonym for
"http://$DOMAIN:80/", so we need to tell Django to listen
on port 80 instead of 8000. This may or may not work:

.. code-block:: bash

    ./manage.py runserver 0.0.0.0:80

Port 80 is privileged. This means that normal users aren't allowed to
listen for connections on port 80; only the root user is. So if you run
the above command as as a normal user, Django will probably tell you
that you don't have permission to access that port.  Fix that problem by
becoming root:

.. code-block:: bash

    sudo -s
    cd $DJANGO_PROJECT_DIRECTORY
    # [activate your virtualenv]
    ./manage.py runserver 0.0.0.0:80

If this tells you that the port is already in use, it probably means
that a web server such as Apache or nginx is already running on the
machine. Shut it down:

.. code-block:: bash

    service apache2 stop
    service nginx stop

When you finally get ``./manage.py runserver 0.0.0.0:80`` running, you
should, at last, be able to go to your web browser and reach your Django
project via http://$DOMAIN/. Congratulations!

Things we need to fix
---------------------

Now, of course, this is the wrong way to do it. It's wrong for the
following reasons:

 * You have put your project in some random directory.
 * You are running Django as root.
 * You have Django serve your static files, and you have DEBUG=True.
 * You are using ``runserver``, which is seriously suboptimal and only
   meant for development.
 * You are using SQLite.

Let's go fix them.
