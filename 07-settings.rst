Production settings
===================

So far the only thing we've done in our production settings was to setup
``ALLOWED_HOSTS``. We still have some work to do. It is absolutely
essential to setup email and the secret key, it is a good idea to setup
logging, and we may also need to setup caching. Most installations will
not need anything beyond these.

Email
-----

Even if your Django application does not use email at all, you must
still set it up. The reason is that your code has bugs. Even if it does
not have bugs, your server will eventually run into an error condition,
such as no disk space, out of memory, or something else going wrong. In
many of these cases, Django will throw a "500 error" to the user and
will try to email you. You really need to receive that email.

First, you need a mail server to which you can connect and ask to send
an email. Such a mail server is called a "smarthost". The mechanism with
which Django connects to the smarthost is pretty much the same as the
one with which your desktop or mobile mail client connects to an
outgoing mail server. However, the term "outgoing mail server" is mostly
used for mailing software, and "smarthost" is used when some unattended
software like your Django app sends email. You can often, but not
always, use your outgoing mail server as smarthost.

I'm using Runbox for my email, and I also use it as a smarthost.  There
are many other providers, one of the most popular being Gmail (I
believe, however, that it's not possible to use Gmail as a smarthost if
all you have is a free account, and even if it is possible, it is hard
to setup).

Let's set it up and then we will discuss more. Add the following to
``/etc/opt/$DJANGO_PROJECT/settings.py``::

    SERVER_EMAIL = 'noreply@$DOMAIN'
    DEFAULT_FROM_EMAIL = 'noreply@$DOMAIN'
    ADMINS = [
        ('$ADMIN_NAME', '$ADMIN_EMAIL_ADDRESS'),
    ]
    MANAGERS = ADMINS

    EMAIL_HOST = '$EMAIL_HOST'
    EMAIL_HOST_USER = '$EMAIL_HOST_USER'
    EMAIL_HOST_PASSWORD = '$EMAIL_HOST_PASSWORD'
    EMAIL_PORT = 587
    EMAIL_USE_TLS = True

SERVER_EMAIL_ is the email address from which emails with error messages
appear to come from. It is set in the "From:" field of the email. The
default is "root@localhost", and while "root" is OK, "localhost" is not,
and some mail servers may refuse the email. The domain name where your
Django application runs is usually OK, but if this doesn't work you can
use any other valid domain. The domain of your email address should work
properly.

If your Django project does not send any emails (other than the error
messages Django will send anyway), DEFAULT_FROM_EMAIL_ does not need to
be specified. If it does send emails, it may be using
`django.core.mail.EmailMessage`_. In order to specify what will be in
the "From:" field of the email, ``EmailMessage`` accepts a
``from_email`` argument at initialization; if this is unspecified, it
will use ``DEFAULT_FROM_EMAIL``. So ``DEFAULT_FROM_EMAIL`` is exactly
what it says: the default ``from_email`` of ``EmailMessage``. It's a
good idea to specify this, because even if your Django project does not
send emails today, it may well do so tomorrow, and the default,
"webmaster@localhost", is not a good option. Remember that with
``EmailMessage`` you are likely to send email to your users, and it
should be something nice. "noreply@$DOMAIN" is usually fine.

ADMINS_ is a list of people to whom error messages will be sent. Make
sure your name and email address are listed there, and also add any
fellow administrators. MANAGERS_ is similar to ``ADMINS``, but for
broken link notifications, and usually you just need to set it to the
same values as ``ADMINS``.

The settings starting with ``EMAIL_`` describe how Django will connect
and authenticate to the mail server. Django will connect to EMAIL_HOST_
and authenticate using EMAIL_HOST_USER_ and EMAIL_HOST_PASSWORD_.
Needless to say, I have used placeholders that start with a dollar sign,
and you need to replace these with actual values. Mine are usually
these::
    
   EMAIL_HOST = 'mail.runbox.com'
   EMAIL_HOST_USER = 'smarthostclient%antonischristofides.com'
   EMAIL_HOST_PASSWORD = 'topsecret'

However, the details depend on the provider and the account type you
have. I don't use my personal email, which is
antonis@antonischristofides.com (Runbox requires you to change @ to %
when you use it as a user name for login), because my personal password
would then be in many ``settings.py`` files in many deployed Django
projects, and I'm not the only administrator of these servers (and even
if I were, I wouldn't know when I would invite another one). So I
created another user (subaccount in Runbox parlance),
"smarthostclient", which I use for that purpose.

There are three ports used for sending email: 25, 465, and 587. The
sender (Django in our case, or your mail client when you send email)
connects to a mail server and gives the email to it; the mail server
then delivers the email to another mail server, and so on, until the
destination is reached. In the old times both the initial submission and
the communication between mail servers was through port 25. Nowadays 25
is mostly used for communication between mail servers only. If you try
to use port 25 (which is the default setting for EMAIL_PORT_), it's
possible that the request will get stuck in firewalls, and even if does
reach the mail server, the mail server is likely to refuse to send the
email. This is because spam depends much on port 25, so policies about
this port are very tight.

The other two ports for email submission are 465 and 587. 465 uses
encryption; just as 80 is for unencrypted HTTP and 443 is for encrypted
HTTP, 25 is for unencrypted SMTP and 465 is for encrypted SMTP.
However, 465 is deprecated in favour of 587, which can handle both
unencrypted and encrypted connections. The client (Django in our case)
connects to the server at port 587, they start talking unencrypted, and
the client may tell the server "I want to continue with encryption", and
then they continue with encryption. Obviously this is done before
authentication, which requires the password to be transmitted.

There are thus two methods to start encryption; one is implicit and the
other one is explicit. When you connect to port 465, which always works
encrypted, the encryption starts implicitly. When you connect to port
587, the two peers (the client and the server) start talking
unencrypted, and at some point the client explicitly tells the server "I
want to continue with encryption". Computer people often use "SSL" for
implicit encryption and "TLS" for explicit, however this is inaccurate;
SSL and TLS are encryption protocols, and do not refer to the method
used to initiate them; you could have implicit TLS or explicit SSL.
Django uses this inaccurate parlance in its settings, where
EMAIL_USE_TLS_ and EMAIL_USE_SSL_ are used to specify whether,
respectively, the connection will use explicit or implicit encryption.
``EMAIL_USE_TLS = True`` should be used with ``EMAIL_PORT = 587``, and
``EMAIL_USE_SSL = True`` with ``EMAIL_PORT = 465``.

To test your settings, start a shell from your Django project:

.. code-block:: bash

    PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT \
    DJANGO_SETTINGS_MODULE=settings \
    su $DJANGO_USER -c \
    "/opt/$DJANGO_PROJECT/venv/bin/python \
    /opt/$DJANGO_PROJECT/manage.py shell"

and enter these commands::

    from django.conf import settings
    from django.core.mail import send_mail

    admin_emails = [x[1] for x in settings.ADMINS]
    send_mail("Test1557", "Hello", settings.SERVER_EMAIL,
              admin_emails)

If something goes wrong, ``send_mail`` will raise an exception;
otherwise you should receive the email.

Because of spam, mail servers are often very picky about which emails
they will accept. It's possible that even if your smarthost accepts the
email, the next mail server may refuse it. For example, I made some
experiments using ``from_email='noreply@example.com'``, ``EMAIL_HOST =
'mail.runbox.com'``, and recipient anthony@itia.ntua.gr (an old email
address of mine). In that case, Runbox accepted the email and
subsequently attempted to deliver it to the mail server of ntua.gr,
which rejected it because it didn't like the sender
(noreply@example.com; I literally used "example.com", and ntua.gr didn't
like that domain). When something like this happens, the test we made
above with ``send_mail`` will appear to work, because ``send_mail``
manages to deliver the email to the smarthost, and the error occurs
after that; not only will we never receive the email, but it is also
likely that we will not receive the failure notification (the returned
email), so it's often hard to know what went wrong and we need to guess.

One thing you can do to lessen the probability of error is to make sure
that the recipient (or at least one of the recipients) has an email
address served by the provider who provides the smarthost. In my case,
the smarthost is ``mail.runbox.com``, and the recipient is
antonis@antonischristofides.com, and the email for domain
antonischristofides.com is served by Runbox. It is unlikely that
``mail.runbox.com`` would accept an email addressed to
antonis@antonischristofides.com if another Runbox server were to
subsequently refuse it. If something like this happened, I believe it
would be a configuration error on behalf of Runbox. But it's very normal
that ``mail.runbox.com`` will accept an email which will subsequently be
refused by ntua.gr or Gmail or another provider downstream.

.. _SERVER_EMAIL: https://docs.djangoproject.com/en/1.10/ref/settings/#server-email
.. _DEFAULT_FROM_EMAIL: https://docs.djangoproject.com/en/1.10/ref/settings/#default-from-email
.. _django.core.mail.EmailMessage: https://docs.djangoproject.com/en/1.10/topics/email/#django.core.mail.EmailMessage
.. _ADMINS: https://docs.djangoproject.com/en/1.10/ref/settings/#admins
.. _MANAGERS: https://docs.djangoproject.com/en/1.10/ref/settings/#managers
.. _EMAIL_HOST: https://docs.djangoproject.com/en/1.10/ref/settings/#email-host
.. _EMAIL_HOST_USER: https://docs.djangoproject.com/en/1.10/ref/settings/#email-host-user
.. _EMAIL_HOST_PASSWORD: https://docs.djangoproject.com/en/1.10/ref/settings/#email-host-password
.. _EMAIL_USE_TLS: https://docs.djangoproject.com/en/1.10/ref/settings/#email-use-tls
.. _EMAIL_USE_SSL: https://docs.djangoproject.com/en/1.10/ref/settings/#email-use-ssl
.. _EMAIL_PORT: https://docs.djangoproject.com/en/1.10/ref/settings/#email-port

Debug
-----

After you have configured email and verified it works, you can now turn
off DEBUG::

    DEBUG = False

Now it's good time to verify that error emails do indeed get sent
properly. You can do so by deliberately causing an internal server
error. A favourite way of mine is to temporarily rename a template file
and make a related request, which will raise a ``TemplateDoesNotExist``
exception. Your browser should show the "server error" page. Don't
forget to rename the template file back to what it was. By the time you
finish doing that, you should have received the email with the full
trace.

.. _using_a_local_mail_server:

Using a local mail server
-------------------------

Usually I don't configure Django to deliver to the smarthost; instead, I
install a mail server locally, have Django deliver to the local mail
server, and configure the local mail server to send the emails to the
smarthost.  There are several reasons why installing a local mail server
is better:

1. Your server, like all Unix systems, has a scheduler, ``cron``, which
   is configured to run certain programs at certain times. For example,
   directory ``/etc/cron.daily`` contains scripts that are executed
   once per day. Whenever a program run by ``cron`` throws an error
   message, ``cron`` emails that error message to the administrator.
   ``cron`` always works with a local mail server. If you don't install
   a local mail server, you will miss these error messages. We will
   later use ``cron`` to clear sessions and to backup the server, and we
   don't want to miss any error messages.

2. While Django attempts to send an error email, if something goes
   wrong, it fails silently. This behaviour is appropriate (the system
   is in error, it attempts to email its administrator with the
   exception, but sending the email also results in an error; can't do
   much more).  Suppose, however, that when you try to verify, as we
   did in the previous section, that error emails work, you find out
   they don't work. What has gone wrong? Nothing is written in any log.
   `Intercepting the communication`_ with ``ngrep`` won't work either,
   because it's usually encrypted. If you use a locally installed mail
   server, you will at least be able to look at the local mail server's
   logs.

   .. _intercepting the communication: http://djangodeployment.com/2016/10/24/how-to-use-ngrep-to-debug-http-headers/

3. Sending an error email might take long. The communication line might
   be slow, or a firewall or the DNS could be misbehaving, and it might
   take several seconds, or even a minute, before Django manages to
   establish a connection to the remote mail server. During this time,
   the browser will be in a waiting state, and a Gunicorn process will
   be occupied. Some people will recommend to send emails from celery
   workers, but this is not possible for error emails. In addition,
   there is no reason to install and program celery just for this
   reason. If we use a local mail server, Django will deliver the email
   to it very fast and finish its job, and the local mail server will
   queue it and send it when possible.

While the most popular mail servers for Debian and Ubuntu are exim and
postfix, I don't recommend them. Mail servers are strange beasts. They
have large and tricky configuration files, because they can do a hell of
things. You will have a hard time understanding the necessary
configuration (which is buried under a hell of other configuration), and
if something goes wrong you will have a hard time debugging it.  I also
see no great educational value in learning it. I used to run mail
servers for years but I've got ridden of all of them; it's not worth the
effort when I can do the same thing at Runbox for € 30 per year. 

Instead, we are going to use ``dma`` (nothing to do with direct memory
access; this is the DragonFly Mail Agent). It's a small mail server that
only does what we want; it collects messages in a queue, and sends them
to a smarthost. It is much easier to configure than the real thing.
Install it like this:

.. code-block:: bash

   apt install dma

It will ask you a couple of questions:

**System mail name**
   You should probably use $DOMAIN here. If that doesn't work, you can
   try to use the domain of your email address.
**Smarthost**
   This is the remote mail server, the smarthost, that is; the one we
   had specified in Django's ``EMAIL_HOST``.

Next, open ``/etc/dma/dma.conf`` in an editor, and uncomment or edit
these directives::

   PORT 587
   AUTHPATH /etc/dma/auth.conf
   SECURETRANSFER
   STARTTLS

(If your smarthost uses implicit encryption, you need to specify ``PORT
465`` instead, and omit the ``STARTTLS``.)

Next, open ``/etc/dma/auth.conf`` and add this line::

   $EMAIL_USER|$EMAIL_HOST:$EMAIL_PASSWORD

(These are placeholders of course, which you need to replace.)

Next, open ``/etc/aliases`` and add this line::

   root: $ADMIN_EMAIL_ADDRESS

Finally, open ``/etc/mailname`` in an editor and make sure it contains
a single line which contains your domain ($DOMAIN).

Let's test it to see if it works:

.. code-block:: bash

   sendmail $ADMIN_EMAIL_ADDRESS

This will pause for input. Type a short email message, and end it with a
line that contains a single fullstop. Check ``/var/log/mail.log`` to
verify it has been delivered to the smarthost (if it says "delivery
successful" it's OK, even if it's preceded by a warning message about
the authentication mechanism), and verify that you have received it.

The next step is to configure Django. You might think that we would set
``EMAIL_HOST = 'localhost'`` and ``EMAIL_PORT = 25``, but this is not
what we will do. ``dma`` does not listen on port 25 or on any other
port. The only way to send emails with it is by using the ``sendmail``
command. Traditionally this has been the easiest and most widely
available way to send emails in Unix, and it is also what ``cron`` uses.
(In the old times, when ``sendmail`` was the only existing mail server,
the practice of using the ``sendmail`` command was standardized, so
today all mail servers create a ``sendmail`` command when they are
installed, which is usually a symbolic link to something else).  We will
install a Django email backend that sends emails in the same way.

.. code-block:: bash

    /opt/$DJANGO_PROJECT/venv/bin/pip install django-sendmail-backend

The only Django configuration we need is this::

   EMAIL_BACKEND = 'django_sendmail_backend.backends.EmailBackend'

The ``dma`` configuration should have been obvious, except for
``/etc/aliases`` and ``/etc/mailname``. These are not dma-specific, they
are also used by exim, postfix, and most other mail servers, and
``/etc/mailname`` may also be used by other programs.

``/etc/aliases`` specifies aliases for email addresses. If ``cron``
decides it needs to send an email, the recipient will most likely be a
mere ``root``. The line we added specifies that ``root`` should be
translated to your actual email address. For Django, ``/etc/aliases``
doesn't matter, since Django will get the recipient email address from
the ``ADMINS`` and ``MANAGERS`` settings.

If a program somehow needs to know the domain used for the email of the
system, it usually takes it from ``/etc/mailname``. Setting that to
``$DOMAIN`` should be fine, but if this doesn't work, you can try
setting it to the domain of your email address.

Secret key
----------

Django uses the SECRET_KEY_ in several cases, for example, when
digitally signing sessions in cookies. If it leaks, attackers might be
able to compromise your system. You should not use the ``SECRET_KEY``
you use in development, because that one is easy to leak, and because
many developers often have access to it, whereas they should not have
access to the production ``SECRET_KEY``.

You can create a secret key in this way::

    import sys

    from django.utils.crypto import get_random_string

    sys.stdout.write(get_random_string(50))

.. _SECRET_KEY: https://docs.djangoproject.com/en/1.10/ref/settings/#secret-key

Logging
-------

Even if your Django apps do no logging, they eventually will.  At some
point one of your users is going to cause an error which you will be
unable to reproduce in the development environment, so you will
introduce some logging calls.  It makes sense to configure logging so
that it is ready for that time. You need a configuration that will write
log messages in ``/var/log/$DJANGO_PROJECT/$DJANGO_PROJECT.log``, and
here it is:

.. code-block:: python

    LOGGING = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'default': {
                'format': '[%(asctime)s] %(levelname)s: '
                          '%(message)s',
            }
        },
        'handlers': {
            'file': {
                'class': 'logging.handlers.'
                         'TimedRotatingFileHandler',
                'filename': '/var/log/$DJANGO_PROJECT/'
                            '$DJANGO_PROJECT.log',
                'when': 'midnight',
                'backupCount': 60,
                'formatter': 'default',
            },
        },
        'root': {
            'handlers': ['file'],
            'level': 'INFO',
        },
    }

Here is the meaning of the various items:

**version**
   This is reserved for the future; for now, it should always be 1.
**disable_existing_loggers**
   Django already has a default logging configuration. If
   ``disable_existing_loggers`` is ``True`` (the default), then this
   configuration will override Django's default, otherwise it will work
   in addition to the default. We really want Django's default
   configuration, which is to email critical errors to the
   administrators.
**root**
   This defines the root logger. You can specify very complicated
   logging schemes, where different loggers will be logging using
   different handlers and different formatters. However, as long as our
   system is small, we only need to specify a single logger, the root
   logger, which uses a single handler (the "file" handler) with a
   single formatter (the "default" formatter). In this example I have
   specified ``'level': 'INFO',`` which means the logger will ignore
   messages with a lower priority (the only lower priority is ``DEBUG``,
   and the higher priorities are ``WARNING``, ``ERROR`` and
   ``CRITICAL``). You can change this as needed, however ``INFO`` is
   reasonable to begin with.
**handlers**
   Here we define the "file" handler, whose class is
   ``logging.TimedRotatingFileHandler``. This essentially logs to a
   file, but it has the added benefit that each midnight it starts a
   new log file, renames the old one, and deletes log files older than
   60 days. In this way it is very unlikely that your disk will fill up
   because of the growing log files escaping your attention.
**formatters**
   This defines a formatter named "default". In a system where I'm using
   this logging configuration, I have this code:

   .. code-block:: python

      import logging

      # ...

      logging.info('Notifying user {} about the agrifields of '
                   'user {}'.format(user, owner))

   and it produces this line in the log file::

      [2016-11-29 04:40:02,880] INFO: Notifying user aptiko about the agrifields of user aptiko

.. _caching:

Caching
-------

The only other setting I expect you to set to a different value from
development is ``CACHES``. How you will set it depends on your needs. I
usually want my caches to persist across reboots, so I specify this:

.. code-block:: python

   CACHES = {
       'default': {
           'BACKEND': 'django.core.cache.backends.filebased.'
                      'FileBasedCache',
           'LOCATION': '/var/cache/$DJANGO_PROJECT/cache',
       }
   }

You also need to create the directory and give it the necessary
permissions:

.. code-block:: bash

   mkdir /var/cache/$DJANGO_PROJECT/cache
   chown $DJANGO_USER /var/cache/$DJANGO_PROJECT/cache

Recompile your settings
-----------------------

Remember that Django runs as $DJANGO_USER and does not (and should not)
have permission to write in directory ``/etc/opt/$DJANGO_PROJECT``,
which is owned by root. Therefore it can't write the Python 2 compiled
file ``settings.pyc``, or the Python 3 compiled files directory
``__pycache__``. In theory you should be compiling it each time you make
a change to your settings:

.. code-block:: bash

    /opt/$DJANGO_PROJECT/venv/bin/python -m compileall \
        /etc/opt/$DJANGO_PROJECT

Of course it's not possible to remember to do this every single time you
change something in the settings. There are two solutions to this. The
first solution, which is fine, is to ignore the problem. If the compiled
file is absent or outdated, Python will compile the source file on the
spot. This will happen whenever each gunicorn worker starts, which is
only when you start or restart gunicorn, and it costs less than 1 ms.
It's really negligible.

The second solution is to create a script
``/usr/local/sbin/restart-$DJANGO_PROJECT``, with the following
contents:

.. code-block:: bash

   #!/bin/bash
   set -e
   /opt/$DJANGO_PROJECT/venv/bin/python -m compileall -q \
        -x /opt/$DJANGO_PROJECT/venv/ /opt/$DJANGO_PROJECT \
        /etc/opt/$DJANGO_PROJECT
   service $DJANGO_PROJECT restart

You must make that script executable:

.. code-block:: bash

   chmod 755 /usr/local/sbin/restart-$DJANGO_PROJECT

You might object that we don't want users other than root to be able to
recompile the Python files or to restart the gunicorn service. The
answer is that they won't be able.  They will be able to execute the
script, but when the script arrives at the point where it compiles the
Python files, they will be denied permission to write the compiled
Python files to the directory; and if the script ever arrives at the
last line, again systemd will deny to restart the service. Making a
script non-executable doesn't achieve anything security-wise; a
malicious user could simply copy it and make the copy executable.

From now on, whenever you want to restart gunicorn, instead of ``service
$DJANGO_PROJECT restart``, you can be using ``restart-$DJANGO_PROJECT``,
which will run the above script. The ``set -e`` command tells bash to
stop executing the script when an error occurs, and the ``-q`` parameter
to ``compileall`` tells to not print the list of files compiled.

.. _clearing_sessions:

Clearing sessions
-----------------

If you use ``django.contrib.sessions``, Django stores session data in
the database (unless you use using a different SESSION_ENGINE_).
Django does not automatically clean up the sessions table, so most of
the sessions remain in the database even after they expire. I've seen
sessions tables in small deployments of only a few requests per minute
grow to several hundreds of GB through the years. You can manually
remove expired sessions by executing ``python manage.py clearsessions``.

To make sure your sessions are being cleared regularly, create file
``/etc/cron.daily/$DJANGO_PROJECT-clearsessions`` with the following
contents:

.. code-block:: bash

   #!/bin/bash
   export PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT
   export DJANGO_SETTINGS_MODULE=settings
   su $DJANGO_USER -c "/opt/$DJANGO_PROJECT/venv/bin/python \
       /opt/$DJANGO_PROJECT/manage.py clearsessions"

Make the file executable:

.. code-block:: bash

   chmod 755 /etc/cron.daily/$DJANGO_PROJECT-clearsessions

In Unix-like systems, cron is the standard scheduler; it executes tasks
at specified times. Scripts in ``/etc/cron.daily`` are executed once
daily, starting at 06:25 (am) local time. The time to which this
actually refers depends on the system's time zone, which you can find by
examining the contents of the file ``/etc/timezone``. In most of my
servers, I use UTC. The time during which these scripts are run doesn't
really matter much, but it's better to do it when the system is not very
busy—especially if some of the scripts are intensive, such as backup
(which we will see in a later chapter).  For time zones with a
positive UTC offset, 06:25 UTC could be a busy time, so you might want
to change the system time zone with this command:

.. code-block:: bash

   dpkg-reconfigure tzdata

There is a way to tell cron exactly at what time you want a task to run,
but I won't go into that as throwing stuff into ``/etc/cron.daily``
should be sufficient for most use cases.

Cron expects all the programs it runs to be silent, i.e., to not display
any output. If they do display output, cron emails that output to the
administrator. This is very neat, because if your tasks only display
output when there is an error, you will be emailed only when there is an
error. However, for this to work, you must setup a local mail server
as explained in :ref:`using_a_local_mail_server`.

.. _SESSION_ENGINE: https://docs.djangoproject.com/en/1.10/ref/settings/#session-engine

Chapter summary
---------------

* Install ``dma`` and (in the virtualenv) ``django-sendmail-backend``

* Make sure ``/etc/dma/dma.conf`` has these contents::

     SMARTHOST $EMAIL_HOST
     PORT 587
     AUTHPATH /etc/dma/auth.conf
     SECURETRANSFER
     STARTTLS
     MAILNAME /etc/mailname

  Also make sure ``/etc/dma/auth.conf`` has these contents::

     $EMAIL_HOST_USER|$EMAIL_HOST:$EMAIL_HOST_PASSWORD

  Make sure ``/etc/mailname`` contains $DOMAIN.

* Create the cache directory:

  .. code-block:: bash

     mkdir /var/cache/$DJANGO_PROJECT/cache
     chown $DJANGO_USER /var/cache/$DJANGO_PROJECT/cache

* Create file ``/etc/cron.daily/$DJANGO_PROJECT-clearsessions`` with the
  following contents:

  .. code-block:: bash

     #!/bin/bash
     export PYTHONPATH=/etc/opt/$DJANGO_PROJECT:/opt/$DJANGO_PROJECT
     export DJANGO_SETTINGS_MODULE=settings
     su $DJANGO_USER -c "/opt/$DJANGO_PROJECT/venv/bin/python \
         /opt/$DJANGO_PROJECT/manage.py clearsessions"

  Make the file executable:

  .. code-block:: bash

     chmod 755 /etc/cron.daily/$DJANGO_PROJECT-clearsessions

* Finally, this is the whole ``settings.py`` file:

  .. code-block:: python

      from django_project.settings.base import *

      debug = false
      allowed_hosts = ['$domain', 'www.$domain']
      databases = {
          'default': {
              'engine': 'django.db.backends.sqlite3',
              'name': '/var/opt/$django_project/$django_project.db',
          }
      }

      server_email = 'noreply@$domain'
      default_from_email = 'noreply@$domain'
      admins = [
          ('$admin_name', '$admin_email_address'),
      ]
      managers = admins
      email_backend = 'django_sendmail_backend.backends.' \
                      'emailbackend'

      logging = {
          'version': 1,
          'disable_existing_loggers': false,
          'formatters': {
              'default': {
                  'format': '[%(asctime)s] %(levelname)s: '
                            '%(message)s',
              }
          },
          'handlers': {
              'file': {
                  'class': 'logging.timedrotatingfilehandler',
                  'filename': '/var/log/$django_project/'
                              '$django_project.log',
                  'when': 'midnight',
                  'backupcount': 60,
                  'formatter': 'default',
              },
          },
          'root': {
              'handlers': ['file'],
              'level': 'info',
          },
      }

     caches = {
         'default': {
             'backend': 'django.core.cache.backends.filebased.'
                        'filebasedcache',
             'location': '/var/cache/$django_project/cache',
         }
     }
