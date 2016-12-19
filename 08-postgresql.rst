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
what this means.

.. warning:: Make sure the locale is right

   When PostgreSQL installs, it uses the encoding specified by the
   default system locale (found in ``/etc/default/locale``).  If this is
   not UTF-8, the databases will be using an encoding other than UTF-8.
   You really don't want that. If you aren't certain, you can check,
   using the procedure I explained in Chapter 1, that the default system
   locale is appropriate. You can also check that PostgreSQL was
   installed with the correct locale with this command:

   .. code-block:: bash

      su postgres -c 'psql -l'

   This will list your databases and some information about them,
   including their locale. Immediately after installation, there should
   be three databases (I explain them later on).

   If you make an error and install PostgreSQL while the locale is
   wrong, the easiest way to fix the problem is to uninstall PostgreSQL
   and delete all the databases:

   .. code-block:: bash

      apt purge postgresql-common

   ``apt remove`` is the opposite of ``apt install``; it uninstalls
   packages. ``apt purge`` does the same as ``apt remove``, but in
   addition it removes data and configuration files. It can be
   dangerous, as you can lose data. Obviously you shouldn't use it if
   you have databases with useful data.

   Purging package ``postgresql`` is not enough, because ``postgresql``
   is just a dependency on another package like ``postgresql-9.4`` (it
   depends on your operating system version), which is the actual
   package with the PostgreSQL server. This, in turn, has a dependency
   on ``postgresql-common``. If you purge ``postgresql-common``, all
   packages that are dependent on it will also be purged, so purging
   ``postgresql-common`` is the easiest way to ensure that your
   PostgreSQL server will be purged.

   The command above should remove all contents of ``/var/lib/postgres``
   (the directory in which databases are stored), but if in doubt you
   can remove anything remaining:

   .. code-block:: bash

      rm -rf /var/lib/postgres

   ``rm`` is the Unix command that removes files. With the ``-r`` option
   it recursively removes directories, and ``-f`` means "ask no
   questions". Obviously you should be very careful. Accidentally
   inserting a space, like ``rm -rf / var/lib/postgres``, means it will
   likely remove everything in the root directory.

   After you purge PostgreSQL, fix your system locale as explained in
   Chapter 1, then re-install PostgreSQL.

   If you have a database with useful data, obviously you can't just do
   this. Fixing the problem is more advanced and isn't covered by this
   chapter; there is a `question at Stackoverflow`_ that treats it, but
   better finish this chapter first to get a grip on the basics.

   .. _question at Stackoverflow: http://stackoverflow.com/questions/5090858/how-do-you-change-the-character-encoding-of-a-postgres-database

Let's now try to connect to PostgreSQL with a client program:

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

   CREATE USER $DJANGO_DB_USER PASSWORD '$DJANGO_DB_PASSWORD';
   CREATE DATABASE $DJANGO_DATABASE OWNER $DJANGO_DB_USER;

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
client communicate in a language, in this case the Hypertext Transfer
Protocol or HTTP. In very much the same way, the PostgreSQL server is
listening on a communication port and a client connects to that port.
The client and the server communicate in the PostgreSQL Frontend/Backend
Protocol.

In the case of the ``psql template1`` command, ``psql``, the PostgreSQL
interactive terminal, is the client. It connects to the server, and gets
commands from you. If you tell it ``\l``, it asks the server for the
list of databases. If you give it an SQL command, it sends it to the
server and gets the response from the server.

When you connect to a web server with your browser, you always provide
the server address in the form of a URL. But here we only provided a
database name. We could have told it the server as follows (but it's not
going to work without a fight, because the user authentication kicks in,
which I explain in the next section):

.. code-block:: bash

   psql --host=localhost --port=5432 template1

You might think ``localhost`` and 5432 is the default, but it isn't. The
default is Unix domain socket ``/var/run/postgresql/.s.PGSQL.5432``.
Let's see what this means.

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
same. The PostgreSQL developers chose to include the "5432" in the name
of the socket as a convenience, in order to signify that this socket
leads to the same PostgreSQL server as the one listening on TCP port
5432.  This is useful in the rare case where many PostgreSQL instances
(called "clusters", which I explain later) are running on the same
machine.

.. hint:: Hidden files

   In Unix, when a file begins with a dot, it's "hidden". This means
   that ``ls`` doesn't normally show it, and that when you use wildcards
   such as ``*`` to denote all files, the shell will not include it.
   Otherwise it's not different from non-hidden files.

   To list the contents of a directory including hidden files, use the
   ``-a`` option:

   .. code-block:: bash

      ls -a /var/run/postgresql

   This will include ``.`` and ``..``, which denote the directory itself
   and the parent directory (``/var/run/postgresql/.`` is the same as
   ``/var/run/postgresql``; ``/var/run/postgresql/..`` is the same as
   ``/var/run``). You can use ``-A`` instead of ``-a`` to include all
   hidden files except ``.`` and ``..``.

PostgreSQL roles and authentication
-----------------------------------

After a client such as ``psql`` connects to the TCP port or to the Unix
domain socket of the PostgreSQL server, it must authenticate before
doing anything else. It must login, so to speak, as a user. Like many
other relational database management systems (RDBMS's), PostgreSQL keeps
its own list of users and has a sophisticated permissions system with
which different users have different permissions on different databases
and tables. This is useful in desktop applications. In the Greek tax
office, for example, employees run a program on their computer, and the
program asks them for their username and password, with which they login
to the tax office RDBMS, which is Oracle, and Oracle decides what this
user can or cannot access.

Web applications changed that. Instead of PostgreSQL managing the users
and their permissions, we have a single PostgreSQL user,
$DJANGO_DB_USER, as which Django connects to PostgreSQL, and this user
has full permissions on the $DJANGO_DB database. The actual users and
their permissions are managed by ``django.contrib.admin``. What a user
can or cannot do is decided by Django, not by PostgreSQL. This is a pity
because ``django.contrib.admin`` (or the equivalent in other web
frameworks) largely duplicates functionality that already exists in the
RDBMS, and because having the RDBMS check the permissions is more robust
and more secure. I believe that the reason web frameworks were developed
this way is independence from any specific RDBMS, but I don't really
know.  Whatever the reason, we will live with that, but I am telling you
the story so that you can understand why we need to create a PostgreSQL
user for Django to connect to PostgreSQL as.

Just as in Unix the user "root" is the superuser, meaning it has full
permissions, and likewise the "administrator" in Windows, in PostgreSQL
the superuser is "postgres". I am talking about the database user, not
the operating system user. There is also an operating system "postgres"
user, but here I don't mean the user that is stored in ``/etc/passwd``
and which you can give as an argument to ``su``; I mean a PostgreSQL
user. The fact that there exists an operating system user that happens
to have the same username is irrelevant.

Let's go back to our innocent looking command:

.. code-block:: bash

   su postgres -c 'psql template1'

As I explained, since we don't specify the database server, ``psql`` by
default connects to the Unix domain socket
``/var/run/postgresql/.s.PGSQL.5432``. The first thing it must do after
connecting is authenticating. We could have specified a user to
authenticate as with the ``--username`` option. Since we did not,
``psql`` uses the default. The default is what the ``PGUSER``
environment variable says, and if this is absent, it is the username of
the current operating system user. In our case, the operating system
user is ``postgres``, because we executed ``su postgres``; so ``psql``
attempts to authenticate as the PostgreSQL user ``postgres``.

To make sure you understand this clearly, try to run ``psql template1``
as root:

.. code-block:: bash

   psql template1

What does it tell you? Can you understand why? If not, please re-read
the previous paragraph. Note that after you have just installed
PostgreSQL, it has only one user, ``postgres``.

So, ``psql`` connected to ``/var/run/postgresql/.s.PGSQL.5432`` and
asked to authenticate as ``postgres``. At this point, you might have
expected the server to request a password, which it didn't. The reason
is that PostgreSQL supports many different authentication methods, and
password authentication is only one of them. In that case, it used
another method, "peer authentication". By default, PostgreSQL is
configured to use peer authentication when the connection is local (that
is, through the Unix domain socket) and password authentication when the
connection is through TCP. So try this instead to see that it will ask
for a password:

.. code-block:: bash

   su postgres -c 'psql --host=localhost template1'

You don't know the ``postgres`` password, so just provide an empty
password and see that it refuses the connection. I don't know the
password either. I believe that Debian/Ubuntu sets no password (i.e.
invalid password) at installation time. You can set a valid password
with ``ALTER USER postgres PASSWORD 'topsecret'``, but don't do that.
There is no reason for the ``postgres`` user to connect to the database
with password authentication, it could be a security risk, and you
certainly don't want to add yet another password to your password
manager.

Let's go back to what we were saying. ``psql`` connected to the socket
and asked to authenticate as ``postgres``. The server decided to use
peer authentication, because the connection is local. In peer
authentication, the server asks the operating system: "who is the user
who connected to the socket?" The operating system replied: "postgres".
The server checks that the operating system user name is the same as the
PostgreSQL user name which the client has requested to authenticate as.
If it is, the server allows. So the Unix ``postgres`` user can always
connect locally (through the socket) as the PostgreSQL ``postgres``
user, and the Unix ``joe`` user can always connect locally as the
PostgreSQL ``joe`` user.

So, in fact, if $DJANGO_USER and $DJANGO_DB_USER are the same (and they
are if so far you have followed everything I said), you could use these
Django settings:

.. code-block:: python

    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql_psycopg2',
            'NAME': '$DJANGO_DATABASE',
            'USER': '$DJANGO_DB_USER',
        }
    }

In this case, Django will connect to PostgreSQL using the Unix domain
socket, and PostgreSQL will authenticate it with peer authentication.
This is quite cool, because you don't need to manage yet another
password. However, I don't recommend it. First, most of your colleagues
will have trouble understanding that setup, and you can't expect
everyone to sit down and read everything and understand everything in
detail. Second, next month you may decide to put Django and PostgreSQL
on different machines, and using password authentication you make your
Django settings ready for that change. It's also better, both for
automation and your sanity, to have similar Django settings on all your
deployments, and not to make some of them different just because it
happens that PostgreSQL and Django run on the same machine there.

Remember that when we created the $DJANGO_DATABASE database, we made
$DJANGO_DB_USER its owner?

.. code-block:: sql

   CREATE DATABASE $DJANGO_DATABASE OWNER $DJANGO_DB_USER;

The owner of a database has full permission to do anything in that
database: create and drop tables; update, insert and delete any rows
from any tables; grant other users permission to do these things; and
drop the entire database. This is by far the easiest and recommended way
to give $DJANGO_DB_USER the required permissions.

Before I move to the next section, two more things you need to know.
PostgreSQL authentication is configurable. The configuration is at
``/etc/postgresql/9.x/main/pg_hba.conf``. Avoid touching it, as it is a
bit complicated. The default (peer authentication for Unix domain socket
connections, password authentication for TCP connections) works fine for
most cases. The only problem you are likely to face is that the default
configuration does not allow connection from other machines, only from
localhost. So if you ever put PostgreSQL on a different machine from
Django, you will need to modify the configuration.

Finally, PostgreSQL used to have users and groups, but the PostgreSQL
developers found out that these two types of entity had so much in
common that they joined them into a single type that is called "role". A
role can be a member of another role, just as a user could belong to a
group. This is why you will see "role joe does not exist" in error
messages, and why ``CREATE USER`` and ``CREATE ROLE`` are exactly the
same thing.

PostgreSQL databases and clusters
---------------------------------

Several pages ago, we gave this command:

.. code-block:: bash

   su postgres -c 'psql template1'

I have explained where it connected and how it authenticated, and to
finish this up I only need to explain why we told it to connect to the
"template1" database.

The thing is, there was actually no theoretical need to connect to a
database. The only two commands we gave it were these:

.. code-block:: sql

   CREATE USER $DJANGO_DB_USER PASSWORD '$DJANGO_DB_PASSWORD';
   CREATE DATABASE $DJANGO_DATABASE OWNER $DJANGO_DB_USER;

I also told you, for experiment, to also provide the ``\l`` command,
which lists the databases.

All three commands are independent of database and would work exactly
the same regardless of which database we are connected to. However,
whenever a client connects to PostgreSQL, it *must* connect to a
database. There is no way to tell the server "hello, I'm user postgres,
authenticate me, but I don't want to connect to any specific database
because I only want to do work that is independent of any specific
database". Since you must connect to a database, you can choose any of
the three that are always known to exist: ``postgres``, ``template0``,
and ``template1``. It is a long held custom to connect to ``template1``
in such cases (although ``postgres`` is a bit better, but more on that
below).

The official PostgreSQL documentation explains ``template0`` and
``template1`` so perfectly that I will simply copy it here:

    CREATE DATABASE actually works by copying an existing database. By
    default, it copies the standard system database named ``template1``.
    Thus that database is the "template" from which new databases are
    made. If you add objects to ``template1``, these objects will be
    copied into subsequently created user databases. This behavior
    allows site-local modifications to the standard set of objects in
    databases. For example, if you install the procedural language
    PL/Perl in ``template1``, it will automatically be available in user
    databases without any extra action being taken when those databases
    are created.

    There is a second standard system database named ``template0``. This
    database contains the same data as the initial contents of
    ``template1``, that is, only the standard objects predefined by your
    version of PostgreSQL. ``template0`` should never be changed after
    the database cluster has been initialized. By instructing CREATE
    DATABASE to copy ``template0`` instead of ``template1``, you can
    create a "virgin" user database that contains none of the site-local
    additions in ``template1``. This is particularly handy when
    restoring a ``pg_dump`` dump: the dump script should be restored in
    a virgin database to ensure that one recreates the correct contents
    of the dumped database, without conflicting with objects that might
    have been added to ``template1`` later on.

There's more about that in `Section 22.3`_ of the documentation. In
practice, I never touch ``template1`` either. I like to have PostGIS in
the template, but what I do is create another template,
``template_postgis``, for the purpose.

.. _section 22.3: https://www.postgresql.org/docs/9.6/static/manage-ag-templatedbs.html

Before explaining what the ``postgres`` database is for, we need to look
at an alternative way of creating users and databases. Instead of using
``psql`` and executing ``CREATE USER`` and ``CREATE DATABASE``, you can
run these commands:

.. code-block:: bash

   su postgres -c "createuser --pwprompt $DJANGO_DB_USER"
   su postgres -c "createdb --owner=$DJANGO_DB_USER $DJANGO_DATABASE"

Like ``psql``, ``createuser`` and ``createdb`` are PostgreSQL clients;
they do nothing more than connect to the PostgreSQL server, construct
``CREATE USER`` and ``CREATE DATABASE`` commands from the arguments you
have given, and send these commands to the server. As I've explained,
whenever a client connects to PostgreSQL, it *must* connect to a
database. What ``createuser`` and ``createdb`` (and other PostgreSQL
utility programs) do is connect to the ``postgres`` database.  So
``postgres`` is actually an empty, dummy database used when a client
needs to connect to the PostgreSQL server without caring about the
database.

I hinted above that it is better to use ``psql postgres`` than ``psql
template1`` (though most people use the latter). The reason is that
sometimes you may accidentally create tables while being connected to
the wrong database. It has happened to me more than once to screw up my
``template1`` database. You don't want to accidentally modify your
``template1`` database, but it's not a big deal if you modify your
``postgres`` database. So use that one instead when you want to connect
with ``psql``. The only reason I so far told you to use the suboptimal
``psql template1`` is that I thought you would be confused by the many
instances of "postgres" (there's an operating system user, a PostgreSQL
user, and a database named thus).

Now let's finally explain what a cluster is. Let's see it with an
example. Remember that nginx reads ``/etc/nginx/nginx.conf`` and listens
on port 80? Well, it's entirely possible to start another instance of
nginx on the same server, that reads ``/home/antonis/nginx.conf`` and
listens to another port. That other instance will have different lock
files, different log files, different configuration files, and can have
different directory roots, so it can be totally independent. It's very
rarely needed, but it can be done (I've done it once to debug a
production server of a problem I couldn't reproduce in development).
Likewise, you can start a second instance of PostgreSQL, that uses
different configuration files and a different data file directory, and
listens on a different port (and different Unix domain socket). Since it
is totally independent of the other instance, it also has its own users
and its own databases, and is served by different server processes.
These server processes could even be run by different operating system
users (but in practice we use the same user, ``postgres``, for all of
them). Each such instance of PostgreSQL is called a cluster. By far most
PostgreSQL installations have a single cluster called "main", so you
needn't worry further about it; just be aware that this is why the
configuration files are in ``/etc/postgresql/9.x/main``, why the data
files are in ``/var/lib/postgresql/9.x/main``, and why the log files are
named ``/var/log/postgresql/postgresql-9.x-main.log``. If you ever
create a second cluster on the same machine, you will be doing something
advanced, like setting up certain kinds of replication. If you are doing
such an advanced thing now, you are probably reading the wrong book.

Further reading
---------------

You may have noticed that I close most chapters with a summary, which,
among other things, repeats most of the code and configuration snippets
of the chapter. In this chapter I have no summary to write, because I
have already written it; it's Section `Getting started with
PostgreSQL`_.  In the rest of the chapter I merely explained it.

I explain in the next chapter, but it is so important that I must repeat
it here, that **you should not backup your PostgreSQL database by
copying its data files from /var/lib/postgresql**. If you do such a
thing, you risk being unable to restore it when you need it. Read the
next chapter for more information.

I hope I wrote enough to get you started. You should be able to use it
in production now, and learn a little bit more and more as you go on.
Its great documentation is the natural place to continue. If you ever do
anything advanced, Gregory Smith's PostgreSQL High Performance is a nice
book.
