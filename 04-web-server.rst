The web server
==============

This chapter is divided in two parts: nginx and Apache. Depending on
which of the two you choose, you only need to read that part.

Both nginx and Apache are excellent choices for a web server. Most
people deploying Django nowadays seem to be using nginx, so, if you
aren't interested in learning more about what you should choose, pick up
nginx.  Apache is also widely used, and it is preferable in some cases.
If you have any reason to prefer it, go ahead and use it.

If you want don't know what to do, choose nginx. If you want to know
more about the pros and cons of each one, I have written `a blog post
about it`_.

.. _a blog post about it: http://djangodeployment.com/2016/11/15/why-nginx-is-faster-than-apache-and-why-you-neednt-necessarily-care/

Installing nginx
----------------

Install nginx like this::

    apt install nginx-light

.. note::

   Instead of ``nginx-light``, you can use packages ``nginx-full`` or
   ``nginx-extras``, which have more modules available. However,
   ``nginx-light`` is enough in most cases.

After you install, go to your web browser and visit http://$DOMAIN/. You
should see nginx's welcome page.

Configuring nginx to serve the domain
-------------------------------------

Create file ``/etc/nginx/sites-available/$DOMAIN`` with the
following contents:

.. code-block:: nginx

    server {
        listen 80;
        listen [::]:80;
        server_name $DOMAIN www.$DOMAIN;
        root /var/www/$DOMAIN;
    }

.. note::

   Again, this is not a valid nginx configuration file until you replace
   ``$DOMAIN`` with your actual domain name.

Create a symbolic link in ``sites-enabled``:

.. code-block:: bash

    cd /etc/nginx/sites-enabled
    ln -s ../sites-available/$DOMAIN .

.. _symboliclinks:

.. hint:: Symbolic links

   A symbolic link looks like a file, but in fact it is a pointer to
   another file. The command

   .. code-block:: bash

      ln -s ../sites-available/$DOMAIN .

   means "create a symbolic link that points to file
   ``../sites-available/$DOMAIN`` and put the link in the current
   directory (``.``). Two dots denote the parent directory, so when the
   current direcotry is ``/etc/nginx/sites-enabled``, ``..`` means the
   parent, ``/etc/nginx``, whereas ``../sites-available`` means "one up,
   then down into ``sites-available``. A single dot designates the
   current directory.

   The command above is exactly equivalent as this:

   .. code-block:: bash

      ln -s ../sites-available/$DOMAIN $DOMAIN

   which means "create a symbolic link that points to file
   ``../sites-available/$DOMAIN`` and give it the name $DOMAIN. If the
   last argument of ``ln -s`` is a directory (for example, ``.``), then
   it creates the symbolic link in there and gives it the same name as
   the actual file.

   You can treat the symbolic link as if it was a file; you can edit it
   with an editor, you can open it with a Python program using
   ``open()``, and in these cases the actual file (the one being pointed
   to by the symbolic link) is opened instead.

   While the order of arguments in the ``ln`` command may seem strange
   at first, it is consistent with the order of arguments in the ``cp``
   command which merely copies files. Just as ``cp source destination``
   copies file ``source`` to file ``destination``, similarly ``ln -s
   is like making a copy of the file, but instead of an actual copy, it
   creates a symbolic link.

   If you list files with `ls -l`, it is clearly indicated
   which file the symbolic link points to. The permissions of the link,
   ``rwxrwxrwx``, may seem insecure, but they are actually irrelevant;
   it is the permissions of the actual file that count.

   Except for symbolic links there are also hard links, which are
   created without the ``-s`` option, but are different and rarely used.
   It is unlikely that you will ever create a hard link, so get used to
   always type ``ln -s``, that is, with the ``-s`` option.

Tell nginx to re-read its configuration:

.. code-block:: bash

    service nginx reload

Finally, create directory ``/var/www/$DOMAIN``, and inside that
directory create a file ``index.html`` with the following contents:

.. code-block:: html

    <p>This is the web site for $DOMAIN.</p>

Fire up your browser and visit http://$DOMAIN/, and you should
see the page you created.

The fact that we named the nginx configuration file (in
``/etc/nginx/sites-available``) ``$DOMAIN`` is irrelevant; any name
would have worked the same, but it's a convention to name it with the
domain name. In fact, strictly speaking, we needn't even have created a
separate file.  The only configuration file nginx needs is
``/etc/nginx/nginx.conf``. If you open that file, you will see that it
contains, among others, the following line::

   include /etc/nginx/sites-enabled/*;

So what it does is read all files in that directory and process them as
if their contents had been inserted in that point of
``/etc/nginx/nginx.conf``.

As we noticed, if you visit http://$DOMAIN/, you see the page you
created. If, however, you visit http://$SERVER_IPv4_ADDRESS/, you should
see nginx's welcome page.  If the host name (the part between "http://"
and the next slash) is $DOMAIN or www.$DOMAIN then nginx uses the
configuration we specified above, because of the ``server_name``
configuration directive which contains these two names. If we use
another domain name, or the server's ip address, there is no matching
``server { ... }`` block in the nginx configuration, so nginx uses its
default configuration. That default configuration is in
``/etc/nginx/sites-enabled/default``. What makes it the default is the
``default_server`` parameter in these two lines:

.. code-block:: nginx

    listen 80 default_server;
    listen [::]:80 default_server;

If someone arrives at my server through the wrong domain name, I don't
want them to see a page that says "Welcome to nginx", so I change the
default configuration to the following, which merely responds with "Not
found":

.. code-block:: nginx

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        return 404;
    }

Configuring nginx for django
----------------------------

Change ``/etc/nginx/sites-available/$DOMAIN`` to the following
(which only differs from the one we just created in that it has the
``location`` block):

.. code-block:: nginx

    server {
        listen 80;
        listen [::]:80;
        server_name $DOMAIN www.$DOMAIN;
        root /var/www/$DOMAIN;
        location / {
            proxy_pass http://localhost:8000;
        }
    }

Tell nginx to reload its configuration::

    service nginx reload

Finally, start your Django server as we saw in the previous chapter;
however, it doesn't need to listen on 0.0.0.0:8000, a mere 8000 is
enough:

.. code-block:: bash

   PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
       su $DJANGO_USER -c \
       "/opt/$DJANGO_PROJECT/venv/bin/python \
       /opt/$DJANGO_PROJECT/manage.py \
       runserver --settings=settings 8000"

Now go to http://$DOMAIN/ and you should see your Django
project in action.

Nginx receives your HTTP request. Because of the ``proxy_pass``
directive, it decides to just pass on this request to another server,
which in our case is localhost:8000.

Now this may work for now, but we will add some more configuration which
we will be necessary later. The ``location`` block actually becomes:

.. code-block:: nginx

   location / {
       proxy_pass http://localhost:8000;
       proxy_set_header Host $http_host;
       proxy_redirect off;
       proxy_set_header X-Forwarded-For $remote_addr;
       proxy_set_header X-Forwarded-Proto $scheme;
       client_max_body_size 20m;
   }

Here is what these configuration directives do:

**proxy_set_header Host $http_host**
   By default, the header of the request nginx makes to the backend
   includes ``Host: localhost``.  We need to pass the real ``Host`` to
   Django (i.e. the one received by nginx), otherwise Django cannot
   check if it's in ``ALLOWED_HOSTS``.
**proxy_redirect off**
   This tells nginx that, if the backend returns an HTTP redirect, it
   should leave it as is. (By default, nginx assumes the backend is
   stupid and tries to be smart; if the backend returns an HTTP redirect
   that says "redirect to http://localhost:8000/somewhere", nginx
   replaces it with something similar to
   http://yourowndomain.com/somewhere". We prefer to configure Django
   properly instead.)
**proxy_set_header X-Forwarded-For $remote_addr**
   To Django, the request is coming from nginx, and therefore the
   network connection appears to be from localhost, i.e. from address
   127.0.0.1 (or ::1 in IPv6). Some Django apps need to know the actual
   IP address of the machine that runs the web browser; they might need
   that for access control, or to use the GeoIP database to deliver
   different content to different geographical areas. So we have nginx
   pass the actual IP address of the visitor in the ``X-Forwarded-For``
   header.  Your Django project might not make use of this information,
   but it might do so in the future, and it's better to set the correct
   nginx configuration from now. When the time comes to use this
   information, you will need to configure your Django app properly; one
   way is to use django-ipware_.

.. _django-ipware: https://github.com/un33k/django-ipware

**proxy_set_header X-Forwarded-Proto $scheme**
    Another thing that Django does not know is whether the request has
    been made through HTTPS or plain HTTP; nginx knows that, but the
    request it subsequently makes to the Django backend is always plain
    HTTP. We tell nginx to pass this information with the
    ``X-Forwarded-Proto`` HTTP header, so that related Django
    functionality such as ``request.is_secure()`` works properly. You
    will also need to set ``SECURE_PROXY_SSL_HEADER =
    ('HTTP_X_FORWARDED_PROTO', 'https')`` in your ``settings.py``.
**client_max_body_size 20m**
   This tells nginx to accept HTTP POST requests of up to 20 MB in
   length; if a request is larger nginx ignores it and returns a 413.
   Whether you really need that setting or not depends on whether you
   accept file uploads. If not, nginx's default, 1 MB, is probably
   enough, and it is better for protection against a denial-of-service
   attack that could attempt to make several large POST requests
   simultaneously.

This concludes the part of the chapter about nginx. If you chose nginx
as your web server, you probably want to skip the next sections and go
to the Chapter summary.

Installing Apache
-----------------

Install Apache like this::

    apt install apache2

After you install, go to your web browser and visit
http://$DOMAIN/. You should see Apache's welcome page.

Configuring Apache to serve the domain
--------------------------------------

Create file ``/etc/apache2/sites-available/$DOMAIN.conf`` with
the following contents:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName $DOMAIN
       ServerAlias www.$DOMAIN
       DocumentRoot /var/www/$DOMAIN
   </VirtualHost>

.. note::

   Again, this is not a valid Apache configuration file until you replace
   ``$DOMAIN`` with your actual domain name, such as "example.com".

Create a symbolic link in ``sites-enabled``:

.. code-block:: bash

    cd /etc/apache2/sites-enabled
    ln -s ../sites-available/$DOMAIN.conf .

.. hint:: Symbolic links

   If you don't know what symbolic links are, I have described them in
   :ref:`the equivalent section for nginx<symboliclinks>`.

.. hint:: Use a2ensite

   Debian-based systems have two convenient scripts, ``a2ensite``,
   meaning "Apache 2 enable site", and its counterpart, ``a2dissite``,
   for disabling a site. The first one merely creates the symbolic link
   as above, the second one removes it. So the manual creation of the
   symbolic link above is purely educational, and it's usually better to
   save some typing by just entering this instead:

   .. code-block:: bash

      a2ensite $DOMAIN

Tell Apache to re-read its configuration:

.. code-block:: bash

    service apache2 reload

Finally, create directory ``/var/www/$DOMAIN``, and inside
that directory create a file ``index.html`` with the following
contents:

.. code-block:: html

    <p>This is the web site for $DOMAIN.</p>

Fire up your browser and visit http://$DOMAIN/, and you should
see the page you created.

The fact that we named the Apache configuration file (in
``/etc/apache2/sites-available``) ``yourowndomain.com`` is irrelevant;
any name would have worked the same, but it's a convention to name it
with the domain name. In fact, strictly speaking, we needn't even have
created a separate file.  The only configuration file Apache needs is
``/etc/apache2/apache2.conf``. If you open that file, you will see that
it contains, among others, the following line::

   IncludeOptional sites-enabled/*.conf

So what it does is read all ``.conf`` files in that directory and
process them as if their contents had been inserted in that point of
``/etc/apache2/apache2.conf``.

As we noticed, if you visit http://$DOMAIN/, you see the page
you created. If, however, you visit http://$SERVER_IP_ADDRESS/, you
should see Apache's welcome page.  If the host name (the part between
"http://" and the next slash) is $DOMAIN or
www.$DOMAIN, then Apache uses the configuration we specified
above, because of the ``ServerName`` and ``ServerAlias`` configuration
directives which contain these two names. If we use another
domain name, or the server's ip address, there is no matching
``VirtualHost`` block in the Apache configuration, so apache uses its
default configuration. That default configuration is in
``/etc/apache2/sites-enabled/000-default.conf``. What makes it the
default is that it is listed first; the ``IncludeOptional`` in
``/etc/apache2/apache2.conf`` reads files in alphabetical order, and
``000-default.conf`` has the ``000`` prefix to ensure it is first.

If someone arrives at my server through the wrong domain name, I don't
want them to see a page that says "It works!", so I change the default
configuration to the following, which merely responds with "Not found":

.. code-block:: apache

    <VirtualHost *:80>
        DocumentRoot /var/www/html
        Redirect 404 /
    </VirtualHost>


Configuring Apache for django
-----------------------------

Change ``/etc/apache2/sites-available/$DOMAIN.conf`` to the
following (which only differs from the one we just created in that it
has the ``ProxyPass`` directive):

.. code-block:: apache

   <VirtualHost *:80>
       ServerName $DOMAIN
       ServerAlias www.$DOMAIN
       DocumentRoot /var/www/$DOMAIN
       ProxyPass / http://localhost:8000/
   </VirtualHost>

In order for this to work, we actually first need to enable Apache
modules ``proxy`` and ``proxy_http``, and we will take the opportunity
to also enable ``headers``, because we will need it soon after:

.. code-block:: bash

   a2enmod proxy proxy_http headers

(Similarly to ``a2ensite`` and ``a2dissite``, ``a2enmod`` and
``a2dismod`` are merely convenient ways to create and delete symbolic
links that point from ``/etc/apache2/mods-enabled`` to
``/etc/apache2/mods-available``.)

Tell Apache to reload its configuration::

    service apache2 reload

Finally, start your Django server as we saw in the previous chapter;
however, it doesn't need to listen on 0.0.0.0:8000, a mere 8000 is
enough:

.. code-block:: bash

   PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
       su $DJANGO_USER -c \
       "/opt/$DJANGO_PROJECT/venv/bin/python \
       /opt/$DJANGO_PROJECT/manage.py \
       runserver --settings=settings 8000"

Now go to http://$DOMAIN/ and you should see your Django project in
action.

Apache receives your HTTP request. Because of the ``ProxyPass``
directive, it decides to just pass on this request to another server,
which in our case is localhost:8000.

Now this may work for now, but we will add some more configuration which
we will be necessary later:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName $DOMAIN
       ServerAlias www.$DOMAIN
       DocumentRoot /var/www/$DOMAIN
       ProxyPass / http://localhost:8000/
       ProxyPreserveHost On
       RequestHeader set X-Forwarded-Proto "http"
   </VirtualHost>

Here is what these configuration directives do:

**ProxyPreserveHost On**
   By default, the header of the request Apache makes to the backend
   includes ``Host: localhost`` We need to pass the real ``Host`` to
   Django (i.e. the one received by Apache), otherwise Django cannot
   check if it's in ``ALLOWED_HOSTS``.
**RequestHeader set X-Forwarded-Proto "http"**
   Another thing that Django does not know is whether the request has
   been made through HTTPS or plain HTTP; Apache knows that, but the
   request it subsequently makes to the Django backend is always plain
   HTTP. We tell Apache to pass this information with the
   ``X-Forwarded-Proto`` HTTP header, so that related Django
   functionality such as ``request.is_secure()`` works properly. You
   will also need to set ``SECURE_PROXY_SSL_HEADER =
   ('HTTP_X_FORWARDED_PROTO', 'https')`` in your ``settings.py``.

   This does not yet play a role because we have configured Apache
   to only serve plain HTTP. If we wanted it to also serve HTTPS, we
   would add a ``<VirtualHost *:443>`` block, which would contain mostly
   the same stuff as the ``<VirtualHost *:80>`` we have already defined.
   One of the differences is that ``X-Forwarded-Proto`` will be set to
   `"https"`.

Chapter summary
---------------

* Install your web server.
* Name the web server's configuration file with the domain name of your
  site.
* Put the configuration file in ``sites-available`` and symlink it from
  ``sites-enabled`` (don't forget to reload the web server).
* Use the ``proxy_pass`` (nginx) or ``ProxyPass`` (Apache) directive to
  pass the HTTP request to Django.
* Configure the web server to pass HTTP request headers ``Host``,
  ``X-Forwarded-For``, and ``X-Forwarded-Proto`` (Apache by default
  passes ``X-Forwarded-For``, so there is no configuration needed for
  that one).
* For nginx, also configure ``proxy_redirect`` and
  ``client_max_body_size``.
