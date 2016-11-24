Settings
========

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

First, you need a mail server.

While you could install exim or postfix and make your machine a mail
server as well, I don't recommend it. Running a mail server can easily
fill in a book by itself. I used to run mail servers for years but I've
got ridden of all of them; it's not worth the effort when I can do the
same thing at runbox.com for € 30 per year. I'm using, you guessed it,
runbox.com, but there are many other providers, one of the most popular
being Gmail (I believe, however, that it's not possible to use Gmail as
an outgoing mail server if all you have is a free account, and even if
it is possible, it is hard to setup). Django will only use the mail
server as an outgoing mail server. When it needs to send an email it
will connect to it, send the email, and that's it. Pretty much in the
same way you send emails from a mail client. The difference is that with
the mail client you also read emails, but Django will do no such thing.

Let's set it up and then we will discuss more. Add the
following to ``/etc/opt/$DJANGO_PROJECT/settings.py``::

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
use any other valid domain.

If your Django project does not send any emails (other than the error
messages Django will send anyway), DEFAULT_FROM_EMAIL_ does not need to
be specified. If it does send emails, it might be using
`django.core.mail.EmailMessage`_. In order to specify what will be in
the "From:" field of the email, ``EmailMessage`` accepts an
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
antonis@antonischristofdes.com (runbox.com requires you to change @ to %
when you use it as a user name for login), because my personal password
would then be in many ``settings.py`` files in many deployed Django
projects, and I'm not the only administrator of these servers (and even
if I were, I wouldn't know when I would invite another one). So I
created another user (subaccount in runbox.com parlance),
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
other one is explicit. When you connect to port 465, which is always
supposed to be encrypted, the encryption starts implicitly. When you
connect to port 587, the two peers (the client and the server) start
talking unencrypted, and at some point the client explicitly tells the
server "I want to continue with encryption". Computer people often use
"SSL" for implicit encryption and "TLS" for explicit, however this is
inaccurate; SSL and TLS are encryption protocols, and do not refer to
the method used to initiate them; you could have implicit TLS or
explicit SSL. Django uses this inaccurate parlance in its settings,
where EMAIL_USE_TLS_ and EMAIL_USE_SSL_ are used to specify whether,
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

And enter these commands::

    from django.conf import settings
    from django.core.mail import send_mail

    admin_emails = [x[1] for x in settings.ADMINS]
    send_mail("Test1557", "Hello", settings.SERVER_EMAIL,
              admin_emails)

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

Advanced email
--------------

I told you a small lie. I said I don't maintain mail servers any more.
Actually I do install exim or postfix locally on my Django servers and
configure Django to use it. I use ``EMAIL_HOST = 'localhost'`` and
Django submits the email to the locally installed mail server, which
subsequently connects to another mail server and submits the email,
exactly as Django does when we configure it like we did in the preceding
sections. It's not a big lie because it's not an installation of a fully
functional mail server that can send and receive email; it's a partially
working server that we call a "satellite".

If you are satisfied with what we did so far, it's fine to skip this
section if you are in a hurry. However, there are three reasons why
installing a local mail server is better:

 1. While Django attempts to send an error email, if something goes
    wrong, it fails silently. This behaviour is appropriate (the system
    is in error, it attempts to email its administration with the
    exception, but sending the email also results in an error; what else
    could be done?). Suppose, however, that when you try to verify that
    error emails get sent, as in the previous section, you find out they
    don't work. What has gone wrong? Nothing is written in any log.
    Intercepting the communication with ``ngrep`` won't work either,
    because it's usually encrypted. If you use a locally installed mail
    server, Django's communication with it will be unencrypted, and any
    subsequent errors will be logged by the mail server and you will be
    able to look at the logs.

 2. Sending an error email might take long. The communication line might
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

 3. Your server, like all Unix systems, has a scheduler, ``cron``, which
    is configured to run certain programs at certain times. For example,
    directory ``/etc/cron.daily`` contains scripts that are executed
    once per day. Whenever a program run by ``cron`` throws an error
    message, ``cron`` emails that error message to the administrator.
    ``cron`` always works with a local mail server. If you don't install
    a local mail server, you will miss these error messages.
 
So, install postfix like this:

.. code-block:: bash

   apt-get install postfix

This will ask you a few questions, to which you should answer thus:

**General type of mail configuration**
   Satellite system. This means that it will not be receiving emails, it
   will only be sending emails, and it will be sending them all to a
   single remote mail server.

**System mail name**
   You should probably use $DOMAIN here. If that doesn't work, you can
   try to use the domain of your email address.

**SMTP relay host**
   This is the remote mail server, followed by a colon and the port,
   such as ``mail.runbox.com:587``.

**Root and postmaster mail recipient**
   Specify your own email address. If ``cron`` attempts to email the
   "root" user about a problem, postfix will treat "root" as an alias
   for your email address.

**Other destinations to accept mail for**
   This is redundant, your answer doesn't matter.

**Force synchronous updates**
   No.

**Local networks**
   Leave the default, which should include the local addresses for IPv4
   and IPv6.

**Mailbox size limit**
   This is redundant, your answer doesn't matter. Leave it at zero.

**Local address extensions**
   Likewise. Leave the default.

**Internet protocols to use**
   All

If you get anything wrong, you can reconfigure it like this:

.. code-block:: bash

   dpkg-reconfigure postfix

We are not complete yet, as the configuration so far has only told
postfix to use port 587 (or possibly 465), but we have not specified
that we need encryption and authentication. For this, add the following
at the end of ``/etc/postfix/main.cf``:

.. code-block:: ini

   smtp_tls_security_level = encrypt

   smtp_sasl_auth_enable = yes
   smtp_sasl_security_options = noanonymous
   smtp_sasl_password_maps = hash:/etc/postfix/smtp_auth

The first directive, on its own, tells it to use explicit encryption. If
you use port 465, you need to add this to enable implicit encryption:

.. code-block:: ini

   smtp_tls_wrappermode = yes

The directives beginning with ``smtp_sasl`` configure authentication.
The first two enable authentication, and the third one specifies that
the username and password can be found in ``/etc/postfix/smtp_auth``.
Create that file with the following contents::

   $EMAIL_HOST $EMAIL_HOST_USER:$EMAIL_HOST_PASSWORD

An example is this::

   mail.runbox.com antonis%antonischristofides.com:topsecret

Because the file contains your password, you should protect it:

.. code-block:: bash

   chmod u=rw,g=r,o= /etc/postfix/smtp_auth

Finally, you need to, let's say, "compile" that file:

.. code-block:: bash

   postmap /etc/postfix/smtp_auth

This will create a binary file ``/etc/postfix/smtp_auth.db``, which is
what postfix will be using during actual operation. After you did all
that, postfix should be working.

Django configuration is now much simpler::

    EMAIL_HOST = 'localhost'
    EMAIL_PORT = 25

You don't need to specify ``EMAIL_USE_TLS``, ``EMAIL_HOST_USER`` or
``EMAIL_HOST_PASSWORD``, because the connection between Django and the
postfix will be unencrypted and without authentication. If anything is
not working, you can check postfix's log files, ``/var/log/mail.log``
and ``/var/log/mail.err``.

Secret key
----------

Django uses the SECRET_KEY_ in several cases, for example, when
digitally signing sessions in cookies. If it leaks, then attackers might
be able to compromise your system. You should not use the ``SECRET_KEY``
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

Caching
-------

Recompile your settings
-----------------------

Chapter summary
---------------
