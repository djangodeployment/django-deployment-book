Gunicorn
========

Why Gunicorn?
-------------

We now need to replace the Django development server with a Python
application server. I will explain later why we need this. For now we
need to select which Python application server to use. There are three
popular servers: mod_wsgi, uWSGI, and Gunicorn.

mod_wsgi is for Apache only, and I prefer to use a method that can be
used with either Apache or nginx. This will make it easier to change the
web server, should such a need arise.

I used uWSGI for a couple of years and was overwhelmed by its features.
Many of them duplicate features that already exist in Apache or nginx or
other parts of the stack, and thus they are rarely, if ever, needed. Its
documentation is a bit chaotic. The developers themselves admit it: "We
try to make our best to have good documentation but it is a hard work.
Sorry for that." I recall hitting problems week after week and spending
hours to solve them each time.

Gunicorn, on the other hand, does exactly what you want and no more. It
is simple and works fine. So I recommend it unless in your particular
case there is a compelling reason to use one of the others, and so far I
haven't met any such compelling reason.

Installing and running Gunicorn
-------------------------------

We will install Gunicorn with ``pip`` rather than with ``apt-get``,
because the packaged Gunicorn (both in Debian 8 and Ubuntu 16.04)
supports only Python 2.

.. code-block:: bash

   /opt/$DJANGO_PROJECT/venv/bin/pip install gunicorn

Now run Django with Gunicorn:

.. code-block:: bash

   su $DJANGO_USER
   source /opt/$DJANGO_PROJECT/venv/bin/activate
   export PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT
   export DJANGO_SETTINGS_MODULE=settings
   gunicorn $DJANGO_PROJECT.wsgi:application

You can also write it as one long command, like this:

.. code-block:: bash

   PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
       DJANGO_SETTINGS_MODULE=settings \
       su $DJANGO_USER -c "/opt/$DJANGO_PROJECT/venv/bin/gunicorn \
       $DJANGO_PROJECT.wsgi:application"

Either of the two versions above will start Gunicorn, which will be listening
at port 8000, like the Django development server did. Visit http://$DOMAIN/,
and you should see your Django project in action.

What actually happens here is that ``gunicorn``, a Python program, does
something like ``from $DJANGO_PROJECT.wsgi import application``. It uses
``$DJANGO_PROJECT.wsgi`` and ``application`` because we told it so in
the command line. Open the file
``/opt/$DJANGO_PROJECT/$DJANGO_PROJECT/wsgi.py`` to see that
``application`` is defined there. In fact, ``application`` is a Python
callable. Now each time Gunicorn receives an HTTP request, it calls
``application`` in a standardized way that is specified by the WSGI
specification. The fact that the interface of this function is
standardized is what permits you to choose between many different Python
application servers such as Gunicorn, uWSGI, or mod_wsgi, and why each
of these can interact with many Python application frameworks like
Django or Flask.

The reason we aren't using the Django development server is that it is
meant for, well, development. It has some neat features for development,
such as that it serves static files, and that it automatically restarts
itself whenever the project files change. It is, however, totally
inadequate for production; for example, it does not support processing
many requests at the same time, which you really want. Gunicorn, on the
other hand, does the multi-processing part correctly, leaving to Django
only the things that Django can do well.

Gunicorn is actually a web server, like Apache and nginx. However, it
does only one thing and does it well: it runs Python WSGI-compliant
applications. It cannot serve static files and there's many other
features Apache and nginx have that Gunicorn does not. This is why we
put Apache or nginx in front of Gunicorn and proxy-pass requests to it.
The accurate name for Gunicorn, uWSGI, and mod_wsgi would be
"specialized web servers that run Python WSGI-compliant applications",
but this is too long, which is why I've been using the vaguer "Python
application servers" instead.

Gunicorn has many parameters that can configure its behaviour. Most of
them work fine with their default values. Still, we need to modify a
few. First, let's install ``gevent``. Make sure the virtualenv is
activated, and run ``pip install gevent``. Next, let's run Gunicorn
again, but this time with a few parameters:

.. code-block:: bash

   su $DJANGO_USER
   source /opt/$DJANGO_PROJECT/venv/bin/activate
   export PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT
   export DJANGO_SETTINGS_MODULE=settings
   gunicorn --worker-class=gevent --workers=1 \
       --log-file=/var/log/$DJANGO_PROJECT/gunicorn.log \
       --bind=127.0.0.1:8000 --bind=[::1]:8000 \
       $DJANGO_PROJECT.wsgi:application 

Here is what these parameters mean:

``--worker-class=gevent``
   There are many ways in which Gunicorn can do multi-processing. The
   default one is ``sync``. With that one, Gunicorn starts a number of
   processes called "workers", and each process, each worker that is,
   serves one request at a time. To serve five concurrent requests, five
   workers are needed; if there are more than five concurrent requests,
   they will be queued.

   ``gevent``, on the other hand, is event-driven. If you don't
   understand what this means, read "Apache vs. nginx" in the Appendix.
   ``sync`` works like Apache (except that the most common setup for
   Apache is for it to use threads, whereas Gunicorn's ``sync`` mode
   uses processes, which consume more memory than threads and are more
   expensive in context switching as well). ``gevent`` works like
   nginx—a single process can serve many concurrent requests, using
   events.

   Note that to use ``gevent``, your Django apps must be thread-safe. If
   you use global variables, for example, it's not going to work;
   if you serve two requests at the same time, your code is running two
   times concurrently, and if one thread of execution changes a global
   variable, this can interfere with the other thread. In this respect,
   ``sync`` is safer, because it can run broken apps. However, if your
   apps are broken, you'd really better fix them, you can't get away
   with it.

   How is it possible for ``gevent`` to work asynchronously when your
   Django code is designed to run synchronously? When your Django code,
   for example, wants to retrieve an object from the database via a
   network connection, the process should get blocked at the point where
   your code says ``x.objects.get(id=18)``. ``gevent`` achieves
   asynchronous behaviour by changing the way the Python library works.
   It replaces some functions which get blocked with asynchronous
   versions that return immediately, allowing ``gevent`` to execute
   other coroutines while waiting for the data to come (a "coroutine" is
   the equivalent of a thread in asynchronous programming).

``--workers=1``
   This parameter specifies how many processes ``Gunicorn`` will start.
   For ``gevent``, you only need one process per processor core. If you
   use ``sync`` you need more, maybe 2 to 5 per processor core.

   The default for this setting is 1. However, even if you use
   ``gevent`` on a single core virtual server, this is such an important
   setting that it's better to specify it explicitly in order to really
   know what you are doing.

``--log-file=/var/log/$DJANGO_PROJECT/gunicorn.log``
   I believe this is self-explanatory.

``--bind=127.0.0.1:8000``
   This tells Gunicorn to listen on port 8000 of the local network
   interface. This is the default, but we specify it here for two
   reasons:

    1. It's such an important setting that you need to see it to know
       what you've done. Besides, you could be running many applications
       on the same server, and one could be listening on 8000, another
       on 8001, and so on. So, for uniformity, always specify this.
    2. We specify ``--bind`` twice (see below), to also listen on IPv6.
       The second time would override the default anyway.

``--bind=[::1]:8000``
   This tells Gunicorn to also listen on port 8000 of the local IPv6
   network interface. This must be specified if IPv6 is enabled on the
   virtual server. It is not specified, things may or may not work, and
   the system may be a bit slower even if things work.

   The reason is that the front-end web server, Apache or nginx, has
   been told to forward the requests to http://localhost:8000/. So it
   will ask the operating system (more exactly, the resolver) what
   "localhost" means. If the system is IPv6-enabled, the resolver will
   reply with two results, ``::1``, which is the IPv6 address for the
   localhost, and ``127.0.0.1``. The web server might then decide to try
   the IPv6 version first. If Gunicorn has not been configured to listen
   to that address, then nothing will be listening at port 8000 of ::1,
   so the connection will be refused. The web server will then probably
   try the IPv4 version, which will work, but it will have made a
   useless attempt first.

   I could make some experiments to determine exactly what happens in
   such cases, and not speak with "maybe" and "probably", but it doesn't
   matter. If your server has IPv6, you must set it up correctly and use
   this option. If not, you should not use this option.

Configuring systemd
-------------------

The only thing that remains is to make Gunicorn start automatically. For
this, we will configure it as a service in systemd.

.. note:: Older systems don't have systemd

   systemd is relatively a novelty. It exists only in Debian 8 and
   later, and Ubuntu 15.04 and later. In older systems you need to 
   start Gunicorn in another way. I recommend supervisor_, which you can
   install with ``apt-get install supervisor``.

   .. _supervisor: http://supervisord.org/

The first program the kernel starts after it boots is systemd. For this
reason, the process id of systemd is 1. Enter the command ``ps 1`` and
you will probably see that the process with id 1 is ``/sbin/init``, but
if you look at it with ``ls -lh /sbin/init``, you will see it's a
symbolic link to systemd.

After systemd starts, it has many tasks, one of which is to start and
manage the system services. We will tell it that Gunicorn is one of
these services by creating file
``/etc/systemd/system/$DJANGO_PROJECT.service``, with the following
contents:

.. code-block:: ini

   [Unit]
   Description=$DJANGO_PROJECT

   [Service]
   User=$DJANGO_USER
   Group=$DJANGO_GROUP
   Environment="PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT"
   Environment="DJANGO_SETTINGS_MODULE=settings"
   ExecStart=/opt/$DJANGO_PROJECT/venv/bin/gunicorn \
       --worker-class=gevent --workers=1 \
       --log-file=/var/log/$DJANGO_PROJECT/gunicorn.log \
       --bind=127.0.0.1:8000 --bind=[::1]:8000 \
       $DJANGO_PROJECT.wsgi:application

   [Install]
   WantedBy=multi-user.target

After creating that file, if you enter ``service $DJANGO_PROJECT
start``, it will start Gunicorn. However, it will not start it
automatically at boot until we tell it ``systemctl enable
$DJANGO_PROJECT``.

The ``[Service]`` section of the configuration file should be
self-explanatory, so I will only explain the other two sections. Systemd
doesn't only manage services; it also manages devices, sockets, swap
space, and other stuff. All these are called units; "unit" is, so to
speak, the superclass. The ``[Unit]`` section contains configuration
that is common to all unit types. The only option we need to specify
there is ``Description``, which is free text. Its purpose is only to
show in the UI of management tools. Although $DJANGO_PROJECT will work
as a description, it's better to use something more verbose. As the
systemd documentation says,

  "Apache2 Web Server" is a good example. Bad examples are
  "high-performance light-weight HTTP server" (too generic) or
  "Apache2" (too specific and meaningless for people who do not know
  Apache).

The ``[Install]`` section tells systemd what to do when the service is
enabled. The ``WantedBy`` option specifies dependencies. If, for
example, we wanted to start Gunicorn before nginx, we would specify
``WantedBy=nginx.service``. This is too strict a dependency, so we just
specify ``WantedBy=multi-user.target``. A target is a unit type that
represents a state of the system. The multi-user target is a state all
GNU/Linux systems reach in normal operations. Desktop systems go beyond
that to the "graphical" target, which "wants" a multi-user system plus a
graphical login screen; but we want Gunicorn to start regardless whether
we have a graphical login screen (we probably don't, as it is a waste of
resources on a server).

As I already said, you tell systemd to automatically start the service
at boot (and automatically stop it at system shutdown) in this way:

.. code-block:: bash

   systemctl enable $DJANGO_PROJECT

Do you remember that in nginx and Apache you enable a site just by
creating a symbolic link to ``sites-available`` from ``sites-enabled``?
Likewise, ``systemctl enable`` does nothing but create a symbolic link.
The dependencies we have specified in the ``[Install]`` section of the
configuration file determine where the symbolic link will be created
(sometimes more than one symbolic links are created). After you enable
the service, try to restart the server, and check that your Django
project has started automatically.

As you may have guessed, you can disable the service like this:

.. code-block:: bash

   systemctl disable $DJANGO_PROJECT

This does not make use of the information in the ``[Install]`` section;
it just removes all symbolic links.

More about systemd
------------------

While I don't want to bother you with history, if you don't read this
section you will eventually get confused by the many ways you can manage
a service. For example, if you want to tell nginx to reload its
configuration, you can do it with either of these commands:

.. code-block:: bash

   systemctl reload nginx
   service nginx reload
   /etc/init.d/nginx reload

Before systemd, the first program that was started by the kernel was
``init``. This was much less smarter than systemd and did not know what
a "service" is. All ``init`` could do was execute programs or scripts.
So if we wanted to start a service we would write a script that started
the service and put it in ``/etc/init.d``, and enable it by linking it
from ``/etc/rc2.d``. When ``init`` brought the system to "runlevel 2",
the equivalent of systemd's multi-user target, it would execute the
scripts in ``/etc/rc2.d``. Actually it wasn't ``init`` itself that did
that, but other programs that ``init`` was configured to run, but this
doesn't matter. What matters is that the way you would start, stop,
or restart nginx, or tell it to reload its configuration, or check its
running status, was this:

.. code-block:: bash

   /etc/init.d/nginx start
   /etc/init.d/nginx stop
   /etc/init.d/nginx restart
   /etc/init.d/nginx reload
   /etc/init.d/nginx status

The problem with these commands was that they might not always work
correctly, mostly because of environment variables that might have been
set, so the ``service`` script was introduced around 2005, which, as its
documentation says, runs an init script "in as predictable an
environment as possible, removing most environment variables and with
the current working directory set to /." So a better alternative for the
above commands was

.. code-block:: bash

   service nginx start
   service nginx stop
   service nginx restart
   service nginx reload
   service nginx status

The new way of doing these with systemd is the following:

.. code-block:: bash

   systemctl start nginx
   systemctl stop nginx
   systemctl restart nginx
   systemctl reload nginx
   systemctl status nginx

Both ``systemctl`` and ``service`` will work the same with your Gunicorn
service, because ``service`` is a backwards compatible way to run
``systemctl``. You can't manage your service with an ``/etc/init.d``
script, because we haven't created any such script (and it would have
been very tedious to do so, which is why we preferred to use supervisor
before we had systemd). For nginx and apache2, all three ways are
available, because most services packaged with the operating system are
still managed with init scripts, and systemd has a backwards compatible
way of dealing with such scripts. In future versions of Debian and
Ubuntu, it is likely that the init scripts will be replaced with systemd
configuration files like the one we wrote for Gunicorn, so the
``/etc/init.d`` way will cease to exist.

Of the remaining two newer ways, I don't know which is better.
``service`` has the benefit that it exists in non-Linux Unix systems,
such as FreeBSD, so if you use both GNU/Linux and FreeBSD you can use
the same command in both. The ``systemctl`` version may be more
consistent with other systemd commands, like the ones for enabling and
disabling services. Use whichever you like.

Chapter summary
---------------

 * Install ``gunicorn`` and ``gevent`` in your virtualenv.
 * Create file ``/etc/systemd/system/$DJANGO_PROJECT.service`` with
   these contents:

   .. code-block:: ini

      [Unit]
      Description=$DJANGO_PROJECT

      [Service]
      User=$DJANGO_USER
      Group=$DJANGO_GROUP
      Environment="PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT"
      Environment="DJANGO_SETTINGS_MODULE=settings"
      ExecStart=/opt/$DJANGO_PROJECT/venv/bin/gunicorn \
          --worker-class=gevent --workers=1 \
          --log-file=/var/log/$DJANGO_PROJECT/gunicorn.log \
          --bind=127.0.0.1:8000 --bind=[::1]:8000 \
          $DJANGO_PROJECT.wsgi:application

      [Install]
      WantedBy=multi-user.target

 * Enable the service with ``systemctl enable $DJANGO_PROJECT``, and
   start/stop/restart it or get its status with ``systemctl $COMMAND
   $DJANGO_PROJECT``, where $COMMAND is start, stop, restart or status.

