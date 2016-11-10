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

I used uwsgi for a couple of years and was overwhelmed by its features.
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

   /usr/local/$DJANGO_PROJECT-virtualenv/bin/pip install gunicorn

Now run Django with Gunicorn:

.. code-block:: bash

   su $DJANGO_USER
   source /usr/local/$DJANGO_PROJECT/bin/activate
   export PYTHONPATH=/etc/$DJANGO_PROJECT:/usr/local/$DJANGO_PROJECT
   export DJANGO_SETTINGS_MODULE=settings
   gunicorn $DJANGO_PROJECT.wsgi:application

You can also write it as one long command, like this:

.. code-block:: bash

   PYTHONPATH=/etc/$DJANGO_PROJECT:/usr/local/$DJANGO_PROJECT \
       DJANGO_SETTINGS_MODULE=settings \
       su $DJANGO_USER -c "/usr/local/$DJANGO_PROJECT/bin/gunicorn \
       $DJANGO_PROJECT.wsgi:application"

Either of the two versions above will start Gunicorn, which will be listening
at port 8000, like the Django development server did. Visit http://$DOMAIN/,
and you should see your Django project in action.

What actually happens here is that ``gunicorn``, a Python program, does
something like ``from $DJANGO_PROJECT.wsgi import application``. It uses
``$DJANGO_PROJECT.wsgi`` and ``application`` because we told it so in
the command line. Open the file
``/usr/local/$DJANGO_PROJECT/$DJANGO_PROJECT/wsgi.py`` to see that
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
   source /usr/local/$DJANGO_PROJECT/bin/activate
   export PYTHONPATH=/etc/$DJANGO_PROJECT:/usr/local/$DJANGO_PROJECT
   export DJANGO_SETTINGS_MODULE=settings
   gunicorn --worker-class=gevent --workers=1 \
       --log-file=/var/log/$DJANGO_PROJECT/gunicorn.log \
       --bind 127.0.0.1:8000 --bind [::1]:8000 \
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

``--bind 127.0.0.1:8000``
   This tells Gunicorn to listen on port 8000 of the local network
   interface. This is the default, but we specify it here for two
   reasons:

    1. It's such an important setting that you need to see it to know
       what you've done. Besides, you could be running many applications
       on the same server, and one could be listening on 8000, another
       on 8001, and so on. So, for uniformity, always specify this.
    2. We specify ``--bind`` twice (see below), to also listen on IPv6.
       The second time would override the default anyway.

``--bind [::1]:8000``
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

Chapter summary
---------------
