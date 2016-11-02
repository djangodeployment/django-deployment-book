====================================================
Deploying Django on a single Debian or Ubuntu server
====================================================

Things you need to know
=======================

Before continuing, please make sure you have the necessary background:

 * You can develop with **Django** and are familiar with executing stuff
   like ``python manage.py runserver``.
 * You understand **virtualenv**.
 * You can create a **Debian** or **Ubuntu** server, login to it with
   ssh, use scp to copy files, and use some basic commands, including
   ``sudo`` and ``apt-get update/upgrade/install/remove``.
 * You can use **DNS** to point your domain name to your server.
 * You have chosen between **apache** and **nginx**.

With the exception of being able to develop with Django, you can get an
introduction to the rest at the Appendix.

Getting started
===============

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
I will be using "yourowndomain.com" instead of the more accurate "the
domain name under which your Django project is running".

Experimenting means we will be trying things. We will be installing your
Django project and do things with it, and then we will be deleting it
and reinstalling it to try things differently as we move on. You must
have mastered setting up a development server from scratch. You should
be able to setup your Django project on a newly installed machine within
a couple of minutes at most, with a sequence of commands similar to the
following::

   apt-get install git python3 virtualenvwrapper
   git clone [your_project's_repository]
   cd your_project's_working_directory
   mkvirtualenv --system-site-packages myproject
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

Now, make sure ``DEBUG=True``, and instead of running the development
server with ``./manage.py runserver`` run it as follows::

    ./manage.py runserver 0.0.0.0:8000

After it starts, go to your web browser and tell it to go to
http://www.yourowndomain.com:8000/. You should see your Django project
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
your virtual server has IPv6 enabled, you can use this::

    ./manage.py runserver [::]:8000

This will cause Django to listen for connections on port 8000, both for
IPv4 and IPv6.

Next problem is that you can't possibly ask your users to use
http://www.yourowndomain.com:8000/, you have to get rid of the ":8000"
part. "http://www.yourowndomain.com/" is actually a synonym for
"http://www.yourowndomain.com:80/", so we need to tell Django to listen
on port 80 instead of 8000. This may or may not work::

    ./manage.py runserver 0.0.0.0:80

Port 80 is privileged. This means that normal users aren't allowed to
listen for connections on port 80; only the root user is. So if you run
the above command as as a normal user, Django will probably tell you
that you don't have permission to access that port.  Fix that problem by
becoming root::

    sudo -s
    cd [your_project_directory]
    [activate your virtualenv]
    ./manage.py runserver 0.0.0.0:80

If this tells you that the port is already in use, it probably means
that a web server such as apache or nginx is already running on the
machine. Shut it down::

    service apache2 stop
    service nginx stop

When you finally get ``./manage.py runserver 0.0.0.0:80`` running, you
should, at last, be able to go to your web browser and reach your Django
project via http://www.yourowndomain.com/. Congratulations!

Now, of course, this is the wrong way to do it. It's wrong for the
following reasons:

 * You have put your project in some random directory.
 * You are running Django as root.
 * You have Django serve your static files, and you have DEBUG=True.
 * You are using ``runserver``, which is seriously suboptimal and only
   meant for development.
 * You are using SQLite.

Let's go fix them.

Users and directories
=====================

Right now your Django project is at ``/root``, or maybe at
``/home/joe``. The first thing we are going to fix is put your Django
project in a proper place.

I will be using ``your_django_project`` as the name of your Django
project.

The user Django will be running as
----------------------------------

It's a good idea to not run Django as root. I create a user specifically
for that, to which I give the same name as the Django app or project. In
our case, we will use ``your_django_project`` as the name of the user:

.. code-block:: bash

    adduser --system --home=/var/local/lib/your_django_project \
        --no-create-home --disabled-password your_django_project

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

Your program files
------------------

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

Your data directory
-------------------

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

Your production settings
------------------------

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

Your settings file and the ``/etc/your_django_project`` directory is
owned by root, and, as with the files in ``/usr/local``, won't be able
to write the compile version, so pre-compile it as root:

.. code-block:: bash

    /usr/local/your_django_project-virtualenv/bin/python -m compileall \
        /etc/your_django_project

Running the Django development server under the new scheme
----------------------------------------------------------

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

 * Create a system user with the same name as your Django project.
 * Put your Django project in ``/usr/local``, with all files owned by
   root.
 * Put your virtualenv in ``/usr/local``, with the directory named like
   your Django project with ``-virtualenv`` appended, with all files
   owned by root.
 * Put your data files in a subdirectory of ``/var/local/lib`` with the
   same name as your Django project, owned by the system user you
   created. If you are using SQLite, the database file will go in there.
 * Put your settings file in a subdirectory of ``/etc`` with the same
   name as your Django project, with all files owned by root.
 * Precompile the files in ``/usr/local/your_django_project`` and
   ``/etc/your_django_project``.
 * Run ``manage.py`` as the system user you created, after specifying
   the environment variables
   ``PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project``
   and ``DJANGO_SETTINGS_MODULE=settings``.


The web server
==============

This chapter is divided in two parts: nginx and apache. Depending on
which of the two you choose, you only need to read that part.

Both nginx and apache are excellent choices for a web server. Most
people deploying Django nowadays seem to be using nginx, so, if you
aren't interested in learning more about what you should choose, pick up
nginx.  Apache is also widely used, and it is preferable in some cases.
If you have any reason to prefer it, go ahead and use it.

If you want don't know what to do, choose nginx. If you want to know
more about the pros and cons of each one, there is an article at the
Appendix.

Installing nginx
----------------

Install nginx like this::

    apt-get install nginx-light

.. note::

   Instead of ``nginx-light``, you can use packages ``nginx-full`` or
   ``nginx-extras``, which have more modules available. However,
   ``nginx-light`` is enough in most cases.

After you install, go to your web browser and visit
http://www.yourowndomain.com/. You should see nginx's welcome page.

Configuring nginx to serve yourowndomain.com
--------------------------------------------

Create file ``/etc/nginx/sites-available/yourowndomain.com`` with the
following contents:

.. code-block:: nginx

    server {
        listen 80;
        listen [::]:80;
        server_name yourowndomain.com www.yourowndomain.com;
        root /var/www/yourowndomain.com;
    }

Create a symbolic link in ``sites-enabled``:

.. code-block:: bash

    cd /etc/nginx/sites-enabled
    ln -s ../sites-available/yourowndomain.com .

Tell nginx to re-read its configuration:

.. code-block:: bash

    service nginx reload

Finally, create directory ``/var/www/yourowndomain.com``, and inside
that directory create a file ``index.html`` with the following
contents:

.. code-block:: html

    <p>This is the web site for yourowndomain.com.</p>

Fire up your browser and visit http://yourowndomain.com/, and you should
see the page you created.

The fact that we named the nginx configuration file (in
``/etc/nginx/sites-available``) ``yourowndomain.com`` is irrelevant; any
name would have worked the same, but it's a convention to name it with
the domain name. In fact, we needn't even have created a separate file.
The only configuration file nginx needs is ``/etc/nginx/nginx.conf``. If
you open that file, you will see that it contains, among others, the
following line::

   include /etc/nginx/sites-enabled/*;

So what it does is read all files in that directory and process them as
if their contents had been inserted in that point of
``/etc/nginx/nginx.conf``.

As we noticed, if you visit http://yourowndomain.com/, you see the page
you created. If, however, you visit http://[server_ip_address]/, you
should see nginx's welcome page.  If the host name (the part between
"http://" and the next slash) is yourowndomain.com or
www.yourowndomain.com, then nginx uses the configuration we specified
above, because of the ``server_name`` configuration directive which
contains these two domain names. If we use another domain name, or the
server's ip address, there is no matching ``server { ... }`` block in
the nginx configuration, so nginx uses its default configuration. That
default configuration is in ``/etc/nginx/sites-enabled/default``. What
makes it the default is the ``default_server`` parameter in these two
lines:

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

Change ``/etc/nginx/sites-available/yourowndomain.com`` to the following
(which only differs from the one we just created in that it has the
``location`` block):

.. code-block:: nginx

    server {
        listen 80;
        listen [::]:80;
        server_name yourowndomain.com www.yourowndomain.com;
        root /var/www/yourowndomain.com;
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

   PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project \
       DJANGO_SETTINGS_MODULE=settings \
       su your_django_project -c \
       "/usr/local/your_django_project-virtualenv/bin/python \
       /usr/local/your_django_project/manage.py runserver 8000"
    
Now go to http://yourowndomain.com/ and you should see your Django
project in action.

Nginx receives your HTTP request. Because of the ``proxy_pass``
directive, it decides to just pass on this request to another server,
which in our case is localhost:8000.

Now this may work for now, but we will add some more configuration which
we will be necessary later. The ``location`` block actually becomes:

.. code-block:: nginx

   location / {
       proxy_pass http://localhost:8000;
       proxy_pass_header Server;
       proxy_set_header Host $http_host;
       proxy_redirect off;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Scheme $scheme;
       proxy_connect_timeout 10;
       proxy_read_timeout 30;
       client_max_body_size 20m;
   }

Here is what these configuration directives do:

**proxy_pass_header Server**
   By default, nginx doesn't pass all the HTTP request headers to the
   backend; it only passes TODO. This directive tells it to also pass
   the ``Server`` header; this is necessary because TODO.
**proxy_set_header Host $http_host**
   The ``Host`` header also needs to be passed. (If you don't understand
   the ``Host`` header, read "How apache/nginx virtual hosts work" in
   the Appendix.) The reason is that when, later, we set
   ``DEBUG=False``, Django will need to know the ``Host`` in order to
   check if it's in ``ALLOWED_HOSTS``.
**proxy_redirect off**
   TODO
**proxy_set_header X-Real-IP $remote_addr**
   To Django, the request is coming from nginx, and therefore the
   network connection appears to be from localhost, i.e. from address
   127.0.0.1 (or ::1 in IPv6). Some Django apps need to know the actual
   IP address of the machine that runs the web browser; they might need
   that for access control, or to use the GeoIP database to deliver
   different content to different geographical areas. So we have nginx
   pass the actual IP address of the visitor in the ``X-Real-IP`` header
   (TODO: Django needs configuration?) Your Django project might not
   make use of this information, but it might do so in the future, and
   it's better to set the correct nginx configuration from now.
**proxy_set_header X-Scheme $scheme**
    Another thing that Django does not now is whether the request has
    been made through HTTPS or plain HTTP; nginx knows that, but the
    request it subsequently makes to the Django backend is always plain
    HTTP. We tell nginx to pass this information with the ``X-Scheme``
    header, so that related Django functionality such as
    ``request.is_secure()`` works properly. (TODO: Does Django need
    configuration?)
**proxy_connect_timeout 10**
    TODO
**proxy_read_timeout 30**
    TODO
**client_max_body_size 20m**
   This tells nginx to accept responses from the Django backend up to 20
   MB; if a response is larger nginx ignores it and returns a 502 (TODO:
   really 502?). 20 MB is a reasonable maximum, unlike nginx's default
   setting, which is TODO.

This concludes the part of the chapter about nginx. If you chose nginx
as your web server, you probably want to skip the next sections and go
to the Chapter summary.

Installing apache
-----------------

Install apache like this::

    apt-get install apache2

After you install, go to your web browser and visit
http://www.yourowndomain.com/. You should see apache's welcome page.

Configuring apache to serve yourowndomain.com
--------------------------------------------

Create file ``/etc/apache2/sites-available/yourowndomain.com.conf`` with
the following contents:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName yourowndomain.com
       ServerAlias www.yourowndomain.com
       DocumentRoot /var/www/yourowndomain.com;
   </VirtualHost>

   TODO: check the above*

Create a symbolic link in ``sites-enabled``:

.. code-block:: bash

    cd /etc/apache2/sites-enabled
    ln -s ../sites-available/yourowndomain.com.conf .

Tell apache to re-read its configuration:

.. code-block:: bash

    service apache2 reload

Finally, create directory ``/var/www/yourowndomain.com``, and inside
that directory create a file ``index.html`` with the following
contents:

.. code-block:: html

    <p>This is the web site for yourowndomain.com.</p>

Fire up your browser and visit http://yourowndomain.com/, and you should
see the page you created.

The fact that we named the apache configuration file (in
``/etc/apache2/sites-available``) ``yourowndomain.com`` is irrelevant;
any name would have worked the same, but it's a convention to name it
with the domain name. In fact, we needn't even have created a separate
file.  The only configuration file apache needs is
``/etc/apache2/apache2.conf``. If you open that file, you will see that
it contains, among others, the following line::

   IncludeOptional sites-enabled/*.conf

So what it does is read all ``.conf`` files in that directory and
process them as if their contents had been inserted in that point of
``/etc/apache2/apache2.conf``.

As we noticed, if you visit http://yourowndomain.com/, you see the page
you created. If, however, you visit http://[server_ip_address]/, you
should see apache's welcome page.  If the host name (the part between
"http://" and the next slash) is yourowndomain.com or
www.yourowndomain.com, then apache uses the configuration we specified
above, because of the ``ServerName`` and ``ServerAlias`` configuration
directives which contain these two domain names. If we use another
domain name, or the server's ip address, there is no matching
``VirtualHost`` block in the apache configuration, so apache uses its
default configuration. That default configuration is in
``/etc/apache2/sites-enabled/000-default.conf``. What makes it the
default is that it is listed first; the ``IncludeOptional`` in
``/etc/apache2/apache2.conf`` reads files in alphabetical order, and
``000-default`` has the ``000`` prefix to ensure it is first.

If someone arrives at my server through the wrong domain name, I don't
want them to see a page that says "Welcome to apache" (TODO: fix), so I
change the default configuration to the following, which merely responds
with "Not found":

.. code-block:: apache

   TODO
    
Configuring apache for django
-----------------------------

Change ``/etc/apache2/sites-available/yourowndomain.com`` to the
following (which only differs from the one we just created in that it
has the ``Location`` block):

.. code-block:: apache

   <VirtualHost *:80>
       ServerName yourowndomain.com
       ServerAlias www.yourowndomain.com
       DocumentRoot /var/www/yourowndomain.com;
       <Location />
         ProxyPass http://localhost:8000;
       </Location
   </VirtualHost>

   TODO: Check the above*

Tell apache to reload its configuration::

    service apache2 reload

Finally, start your Django server as we saw in the previous chapter;
however, it doesn't need to listen on 0.0.0.0:8000, a mere 8000 is
enough:

.. code-block:: bash

   PYTHONPATH=/etc/your_django_project:/usr/local/your_django_project \
       DJANGO_SETTINGS_MODULE=settings \
       su your_django_project -c \
       "/usr/local/your_django_project-virtualenv/bin/python \
       /usr/local/your_django_project/manage.py runserver 8000"
    
Now go to http://yourowndomain.com/ and you should see your Django
project in action.

Apache receives your HTTP request. Because of the ``ProxyPass``
directive, it decides to just pass on this request to another server,
which in our case is localhost:8000.

Now this may work for now, but we will add some more configuration which
we will be necessary later. The ``Location`` block actually becomes:

.. code-block:: apache

   <Location />
       ProxyPass http://localhost:8000;
       ProxyPreserveHost On
   </Location>

Here is what these configuration directives do:

TODO: Write the list and possibly expand it, reading about nginx above.

Chapter summary
---------------

* Install your web server.
* Name the web server's configuration file with the domain name of your
  site.
* Put the configuration file in ``sites-available`` and symlink it from
  ``sites-enabled`` (don't forget to reload the web server).
* Use the ``proxy_pass`` (nginx) or ``ProxyPass`` (apache) directive to
  pass the HTTP request to Django.
* Configure the web server to pass HTTP request headers ``Server``,
  ``X-Real-IP``, and ``X-Scheme``.
* TODO: proxy_redirect, connect timeout, read timeout, client
  _max_body_size

Serving static files
====================

Appendix
========

TODO: Environment variables

TODO: su and sudo

TODO: apache vs nginx

TODO: How apache/nginx virtualhosts work


.. hint:: Debian or Ubuntu?

   These two operating systems are practically the same system. You have
   probably already chosen one of the two to work with, and there is no
   reason to reconsider.

   If you haven't chosen yet, and you want to know nothing about this,
   go ahead and pick up the latest LTS version of Ubuntu, which
   currently is 16.04 (and will continue to be so until April 2018).

   The reason I recommend Ubuntu is mostly that it is more popular and
   therefore has better support by virtual server providers. Ubuntu's
   Long Term Support versions also have five years of support instead of
   only three for Debian (though recently Debian has started to offer
   LTS support but it's kind of unofficial). On the other hand I feel
   that Ubuntu sometimes rushes a little bit too much to get the latest
   software versions in the operating system release, whereas Debian can
   be a little bit more stable; but this is just a feeling, I have no
   hard data. I use Debian, but this is a personal preference because
   sometimes I'm too much of a perfectionist (with deadlines) and I want
   things my own way.
