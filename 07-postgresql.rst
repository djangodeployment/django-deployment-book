PostgreSQL
==========

Why PostgreSQL?
---------------

So far we have been using SQLite. Can we continue to do so? The answer,
as always, is "it depends". Most probably you can't.

I'm using SQLite in production in one application I've made for an
eshop hosted by BigCommerce. It gets the orders from the BigCommerce API
and formats them on a PDF for printing on labels. It has no models, and
all the data is stored in BigCommerce. The only significant data stored
in SQLite is the users' names and passwords used for login, by
``django.contrib.auth``. It's hardly three users. Recreating them would
be easier than maintaining a PostgreSQL installation. So SQLite it is.

What if your database is small and you don't have many users, but you
store mission-critical data in the database? That's a hard one. The
thing is, no-one really knows if SQLite is appropriate, because no-one
is using it for mission-critical data. Thunderbird doesn't use it for
storing emails, but for storing indexes, which can be recreated.
Likewise for Firefox. The `SQLite people claim`_ it's appropriate for
mission-critical applications, but industry experience on that is
practically nonexistent. I've never seen corruption in SQLite. I've seen
corruption in PostgreSQL, but we are comparing apples to oranges. I have
a gut feeling (but no hard data) that I can trust SQLite more than
MySQL.

If I ever choose to use SQLite for mission-critical data, I will make
sure I not just backup the database file, but also backup a plain text
dump of the database. I trust plain text dumps more than database files
in case there is silent corruption that can go unnoticed for some time.

As for MySQL, I never understood why it has become so popular when
there's PostgreSQL around. My only explanation is it was marketed
better. PostgreSQL is more powerful, it is easier, and it has better
documentation. If you have a reason to use MySQL, it's probably that you
already know it, or that people around you know it (e.g. it is
company policy). In that case, hopefully you don't need any help from
me. Otherwise, choose PostgreSQL and read the rest of this chapter.

.. _SQLite people claim: https://www.sqlite.org/testing.html

Getting started with PostgreSQL
-------------------------------

You may have noticed that I prefer to tell you to do things first and
then explain them. Same thing again. We will quickly install PostgreSQL
and configure Django to use it. You won't be understanding clearly what
you are doing. After we finish it, you have some long sections to read.
You *must* read them, however. **The way to avoid doing the reading is
to forget about PostgreSQL and continue using SQLite.** It is risky to
put your customer's data on a system that you don't understand and that
you've set up just by blindly following instructions.

.. code-block:: bash

   apt install postgresql

This will install PostgreSQL and create a cluster; I will explain later
what this means. Let's now try to connect to PostgreSQL with a client
program:

.. code-block:: bash

   su postgres -c 'psql template1'

This connects you with the "template1" database and gives you a prompt
ending in ``#``. You can give it some commands like ``\l`` to list the
databases (there are three just after installation). Let's create a
user and a database. I will use placeholders $DJANGO_DB_USER,
$DJANGO_DB_PASSWORD, and $DJANGO_DATABASE. We normally use the same as
$DJANGO_PROJECT for both $DJANGO_DB_USER and $DJANGO_DATABASE, and I
have the habit of using the SECRET_KEY as the database password, but in
principle all these can be different; so I will be using these different
placeholders here to signal to you that they denote something different.

.. code-block:: sql

   CREATE USER $DJANGO_DBUSER PASSWORD '$DJANGO_DB_PASSWORD';
   CREATE DATABASE $DJANGO_DATABASE OWNER $DJANGO_DBUSER;

The command to exit ``psql`` is ``\q``.

Next, we need to install ``psycopg2``:

.. code-block:: bash

    apt install python-psycopg2 python3-psycopg2

This will work only if you have created your virtualenv with the
``--system-site-packages`` option, which is what I told you to do many
pages ago. Otherwise, you need to ``pip install psycopg2`` inside the
virtualenv. Most people do it in the second way. However, attempting to
install ``psycopg2`` with ``pip`` will require compilation, and
compilation can be tricky, and different ``psycopg2`` versions might
behave differently, and in my experience the easiest and safest way is
to install the version of ``psycopg2`` that is packaged with the
operating system. If your site-wide Python installation is clean
(meaning you have used ``pip`` only in virtualenvs),
``--system-site-packages`` works great.

Finally, change your ``DATABASES`` setting to this:

.. code-block:: python

    DATABASES = {
        'default': {
            'ENGINE': 'django.contrib.gis.db.backends.postgis',
            'NAME': '$DJANGO_DATABASE',
            'USER': '$DJANGO_DB_USER',
            'PASSWORD': '$DJANGO_DB_PASSWORD',
            'HOST': 'localhost',
            'PORT': 5432,
        }
    }

From now on, Django should be using PostgreSQL (you may need to restart
Gunicorn). You should be able to setup your database with this:

.. code-block:: bash

    PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
    DJANGO_SETTINGS_MODULE=settings \
    su $DJANGO_USER -c \
    "/opt/$DJANGO_PROJECT/venv/bin/python \
    /opt/$DJANGO_PROJECT/manage.py migrate"


PostgreSQL connections
----------------------

A short while ago we run this innocent looking command:

.. code-block:: bash

   su postgres -c 'psql template1'

Now let's explain what this does. Brace yourself, as it will take
several sections. Better go make some tea, relax, and come back.

A web server listens on TCP port 80 and a client, usually a browser,
connects to that port and asks for some information. The server and the
client communicate in a language, in this case the HTTP In very much the
same way, the PostgreSQL server is listening on a communication port and
a client connects to that port. The client and the server communicate in
the PostgreSQL Frontend/Backend Protocol.

In the case of the ``psql template1`` command, ``psql``, the PostgreSQL
interactive terminal, is the client. It connects to the server, and gets
commands from you. If you tell it ``\l``, it asks the server for the
list of databases. If you give it an SQL command, it sends it to the
server and gets the response from the server.

When you connect to a web server with your browser, you always provide
the server address in the form of a URL. But here we only provided a
database name. We could have told it the server (but it's not going to
work without a fight, because the user authentication kicks in, which I
explain in the next section):

.. code-block:: bash

   psql --host=localhost --port=5432 template1

You might think that ``localhost`` and 5432 is the default, but it
isn't. The default is Unix domain socket
``/var/run/postgresql/.s.PGSQL.5432``. Let's see what this means.

If you think about it, TCP is nothing more than a way for different
processes to communicate. One process, the browser, opens a
communication channel to another process, the web server. Unix domain
sockets are an alternative interprocess communication system that has
some advantages but only works on the same machine. Two processes on the
same machine that want to communicate can do so via a socket; one
process, the server, will create the socket, and another, the client,
will connect to the socket. One of the philosophies of Unix is that
everything looks like a file, so Unix domain sockets look like files,
but they don't occupy any space on your disk. The client opens what
looks like a file, and sends and receives data from it.

When the PostgreSQL server starts, it creates socket
``/var/run/postgresql/.s.PGSQL.5432``. The "5432" is nothing of meaning
to the system; if the socket had been named
``/var/run/postgresql/hello.world``, it would have worked exactly the
same. The PostgreSQL developers chose to add the "5432" in the name of
the socket as a convenience, in order to signify that this socket leads
to the same PostgreSQL server as the one listening on TCP port 5432.
This is useful in the rare case where many PostgreSQL instances are
running on the same machine.

PostgreSQL users and authentication
-----------------------------------

