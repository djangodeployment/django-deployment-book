DNS
===

Introduction to the DNS
-----------------------

In this book, you will find that I like to show you the code first, even
if you don't understand it clearly, and then explain to you how things
work. Unfortunately, I cannot do that with DNS. You need to understand
it first and then write the code. **The big problem with DNS is that if
you screw things up, even if you fix or revert things, it may be days
before the system works again**. So you need to read carefully.

When you open your browser and type http://djangodeployment.com/, the
first thing your browser does is find the IP address of the machine
djangodeployment.com. For this, it asks a component of the operating
system called the "resolver": "What is the IP address of
djangodeployment.com?"  After some time (usually from a few ms to a few
seconds), the resolver replies: "It's 71.19.145.109". The browser then
proceeds to open a TCP connection on port 80 of that address and use
HTTP to request the required information (in our case the home page of
djangodeployment.com).

.. note:: What about IPv6?

   If your computer has an IPv6 connection to the Internet, your browser
   will actually first ask the resolver for the IPv6 address of server. For
   djangodeployment.com, the resolver will eventually reply "It's
   2605:2700:0:3::4713:916d". The browser will then attempt to connect to
   that IPv6 address. If there is any kind of error, such as the resolver
   being unable to find an IPv6 address (many web servers aren't yet
   configured to use one), or the IPv6 address not responding (network
   errors are still more frequent with IPv6 than IPv4), the browser will
   fall back to using the IPv4 address, as I explained above.

The only thing the resolver does is ask another machine to do the actual
resolving; that other machine is called a name server. Most likely you
are using a name server provided by your Internet Service Provider. I
will be calling that name server "your name server", although it's not
exactly yours; but it's the one you are using.

.. tip:: Which is my name server?

   On Unix-like machines (including Mac OS X), the name server used is
   stored in file ``/etc/resolv.conf``; the file is usually setup
   during DHCP, but on systems with a static IP address it is often
   edited manually.  On Windows, you can determine the name server by
   typing the command 'ipconfig /all', where it shows as "DNS Servers";
   it is setup during DHCP, but on systems with a static IP address it
   is often edited manually in the network properties. Your system may
   be configured to use more than one name server, in which case it
   chooses one and uses another if the first one does not respond.

   You might find out that the name server is your aDSL router. Actually
   your aDSL router is merely a so-called "forwarding" name server,
   which only transfers the query to another name server, which is the
   one that does the real magic. You can find which one it is by logging
   in your router's web interface and browsing through its settings. It
   is setup during the establishment of the aDSL connection.

   When I say "your name server" I don't mean the forwarding name
   server, but the one that does the real job.

In order to find out the address that corresponds to a name, your name
server makes a series of questions to other name servers on the
Internet:

1. First, your name server picks up one of thirteen so-called "root name
   servers". The IP addresses of these thirteen name servers are
   well-known (the official list is at
   http://www.internic.net/domain/named.root) and generally do not
   change, and your name server is preprogrammed to use them.  Your name
   server tells the chosen root name server something like this: "Hello,
   I'd like to know the IP address of djangodeployment.com please."

2. The root name server replies: "Hi. I don't know the address of
   djangodeployment.com; you should ask one of these name servers,
   which are responsible for all domain names ending in '.com'" (and it
   supplies a number of IP addresses (actually thirteen).

3. Your name server picks up one of the .com name servers and asks it:
   "Hello, I'd like to know the IP address of djangodeployment.com
   please."

4. The .com name server replies: "Hi. I don't know the address of
   djangodeployment.com; you should ask one of these name servers,
   which are responsible for djangodeployment.com" (and it supplies a
   number of IP addresses, which at the time of this writing are
   three).

5. Your name server picks up one of the three name servers and asks it:
   "Hello, I'd like to know the IP address of djangodeployment.com
   please."

6. The djangodeployment.com name server replies: "Sure,
   djangodeployment.com is 71.19.145.109".

After your name server gets this information, it replies to the
resolver, which in turn replies to your browser.

In this example, there were only six steps, but they could be more; for
example, if you try to resolve cs.man.ac.uk, first the root servers will
be asked, these will direct to the .uk name servers, which will direct
to the .ac.uk name servers, and so on, for a total of 10 steps (this is
not always the case; when resolving itia.civil.ntua.gr, the .gr servers
refer you to the .ntua.gr servers, and these in turn refer you directly
to the itia.civil.ntua.gr servers, for a total of 8 steps).

All this discussion between servers takes time and network traffic, so
it only happens the first time you ask to connect to the web page. The
results of the DNS query are heavily cached in order to make it faster
for the next times. Typically web browsers cache such results for about
half an hour, or until browser restart. Most important, however, your
name server caches results for much longer. In fact, the response (6)
above is not exactly what I wrote; instead, it is "Sure,
djangodeployment is 71.19.145.109, and you can cache this information
for up to 8 hours". Equally important, the response (4) is "I don't know
the address of djangodeployment.com; you should ask one of these three
name servers, which are responsible for djangodeployment.com, and you
can cache this information (i.e. the list of name servers that are
responsible for djangodeployment.com) for up to two days". Caching times
are configurable to various degrees and are usually from 5 minutes to 48
hours, but caching for a whole week is not uncommon. Rarely does your
name server need to go through the complete list of steps; most often it
will have cached the name servers for the top level domain, and
sometimes it will also have cached some lower stuff.

So here is the big problem with DNS: it's not hard to get it right (it's
easier than writing a Django program), but if you make the slightest
error you might be stuck with the wrong information for up to two days
(or even a week). If you make an error when configuring your domain
name, and a customer attempts to access your site, the error may be
cached by the customer's name server for up to two days, and you can do
nothing about it except fix the error and wait. There is no way to send
a signal to all the name servers of the world and tell them "hey, please
invalidate the cache for djangodeployment.com". Different customers or
visitors of your site will experience different amounts of downtime,
depending on when exactly their local name server will decide to expire
its cache.

Registering a domain name
-------------------------

You register a domain name with a registrar. Registrars are companies
that provide the service of registering a domain name for you. These
companies are authorized by ICANN, the organization ultimately
responsible for domain names. So, before registering a domain name, you
first need to select a registrar, and there are many. I'm using
BookMyName.com, a French registrar which I selected more or less at
random. Its web site is unpolished but it works. Another French
registrar, particularly popular in the free software community, is
Gandi, but it's a bit more expensive than others. The most popular
registrar worldwide is GoDaddy, but it supported SOPA, and for me that's
a showstopper. Another interesting option is Namecheap; I think its
software is nice and its prices are reasonable. If you don't know what
to do, choose that one. There are also dozens of other options, and it's
fine to choose another one. Note that I'm not affiliated with any
registrar (and certainly none of the four I've mentioned).

For practice, you can go and register a cheap test domain; Namecheap,
for example, sells some domains for $0.88 per year. Go get one now so
that you can start messing around with it. Below I use ".com" as an
example, but if your domain is different ($0.88 domains certainly aren't
.com) it doesn't matter, exactly the same rules apply.

When you register a .com domain name at the registrar's web site, two
things happen:

1. The registrar configures some name servers to be the name servers
   for the domain. For example, when I registered djangodeployment.com
   at the web site of bookmyname.com, bookmyname.com configured three
   name servers (nsa.bookmyname.com, nsb.bookmyname.com, and
   nsc.bookmyname.com) as the djangodeployment.com name servers. These
   are the three servers that are involved in steps 5 and 6 of the
   resolving procedure that I presented in the previous section. I am
   going to call them the **domain's name servers**.

2. The registrar notifies the .com name servers that domain
   djangodeployment.com is registered, and that the site name servers
   are the three mentioned above. I am going to call the .com name
   servers the **upstream name servers**. If your domain is
   mydomain.co.uk, the upstream name servers are those responsible for
   .co.uk.


.. _adding_dns_records:

Adding records to your domain
-----------------------------

The DNS database consists of records. Each record maps a name to a
value. For example, a record says that the name djangodeployment.com
corresponds to the value 71.19.145.109. Your registrar provides a web
interface with which you can add, remove and edit records (in Namecheap
you need to go to the Dashboard, Domain list, Manage (the domain),
Advanced DNS). Go to your registrar's interface and, for the test domain
you created, create the following records (remember that
$SERVER_IPv4_ADDRESS and $SERVER_IPv6_ADDRESS are placeholders and you
need to replace them with something else; also omit the "AAAA" records
if your server doesn't have an IPv6 address):

==== ==== ===== ====================
Name Type TTL   Value
==== ==== ===== ====================
@    A    300   $SERVER_IPv4_ADDRESS
@    AAAA 300   $SERVER_IPv6_ADDRESS
www  A    300   $SERVER_IPv4_ADDRESS
www  AAAA 300   $SERVER_IPv6_ADDRESS
==== ==== ===== ====================

Each record has a type. There are many different types of records, but
the ones you need to be aware of here are A, AAAA, and CNAME. "A" defines
an IPv4 address, whereas "AAAA" defines an IPv6 address. We will deal
with CNAME a bit later.

When you see "@" as a name, I mean a literal "@" symbol. This is
shorthand for writing the domain itself. If your domain is mydomain.com,
then whether you enter "mydomain.com." (with a trailing dot) or "@" in
the field for the name is exactly the same thing. Some registrars might
be allowing only the shorthand "@", but often it is allowed to write
"mydomain.com.". Use the "@", which is more common. The first of these
four records means that the domain itself resolves to
$SERVER_IPv4_ADDRESS. Likewise for the second record.

If your domain is mydomain.com, the next two records define the IP
addresses for www.mydomain.com. In the field for the name, you can
either write "www.mydomain.com." (with a trailing dot), or "www",
without a trailing dot. Use the latter, which is more common. In the
rest of the text, I will be using $DOMAIN and www.$DOMAIN instead of
mydomain.com and www.mydomain.com, and you should understand that you
need to replace "$DOMAIN" with your actual domain.

These four records are normally all you need to set. In theory you can
set www.$DOMAIN to point to a different server than $DOMAIN, but this is
uncommon. You can also define ftp.$DOMAIN and whateverelse.$DOMAIN, but
this is often not needed.

The TTL, meaning "time to live", is the maximum allowed caching time.
When a name server asks the domain's name server for the IPv4 address of
$DOMAIN, the domain's name server will reply "$DOMAIN is 71.19.145.109,
and you can cache this information for 300 seconds". Don't make it less
than 300; it will increase the number of queries your visitors will
make, thus making responses a bit slower; and some name servers will
ignore the TTL if it's less than 300 and use 300 anyway.  A common
tactic is to use a large value (say 28800), and when for some reason you
need to switch to another server, you reduce that to 300, wait at least
8 hours (28800 seconds), then bring the server down, change the DNS to
point to the new server, then start the new server. If planned correctly
and executed without problems, the switch will result in a downtime of
no more than 300 seconds. After this is finished, you change the TTL to
28800 again.

You can usually leave the TTL field empty. In that case, a default
TTL applies. The default TTL for the zone ("zone" is more or less the
same as a domain) is normally configurable, but this may depend on the
web interface of the registrar.

CNAME records are a kind of alias. For example, one of the domains I'm
managing is openmeteo.org, and its database is like this:

======= ===== ===== ====================================
Name    Type  TTL   Value
======= ===== ===== ====================================
@       A     300   83.212.168.232
@       AAAA  300   2001:648:2ffc:1014:a800:ff:feb1:6047
www     CNAME 300   ilissos.openmeteo.org.
ilissos A     300   83.212.168.232
ilissos AAAA  300   2001:648:2ffc:1014:a800:ff:feb1:6047
======= ===== ===== ====================================

The machine that hosts the web service for openmeteo.org is called
ilissos.openmeteo.org. When the name server is queried for
www.openmeteo.org, it replies: "Hi, www.openmeteo.org is an alias; the
canonical name is ilissos.openmeteo.org." So then it has to be queried
again for ilissos.openmeteo.org. (However, you cannot use CNAME for the
domain itself, only for other hosts within the domain.) On the right
hand side of CNAMEs, you should always specify the fully qualified
domain name **and end it with a dot**, such as "ilissos.openmeteo.org.",
as in the example above.

I used to use CNAMEs a lot, but now I avoid them, because they make
first-time visits a little slower. Assume you want to visit
"http://www.openmeteo.org/synoptic/irma". Then these things happen:

1. www.openmeteo.org is resolved, and it turns out to be an alias of
   ilissos.openmeteo.org.

2. ilissos.openmeteo.org is resolved to an IP address.

3. The request http://www.openmeteo.org/synoptic/irma is sent to the IP
   address. The web server redirects it to
   http://openmeteo.org/synoptic/irma, without the www.

4. The request http://openmeteo.org/synoptic/irma is sent to the IP
   address, and it is redirected to
   http://openmeteo.org/synoptic/irma/, because I'm using
   ``APPEND_SLASH = True`` in Django's settings.

5. The request http://openmeteo.org/synoptic/irma/ is sent to the IP
   address, and this time a proper response is returned.

All these steps take a small amount of time which may add up to one
second or more. This is only for the first request of first time
visitors, but today people have little patience, and it's a good idea
for the visitor's browser to start drawing something on the screen
within at most one second, otherwise you will be losing a non-negligible
number of visitors. Besides, a high quality web site should not have
unnecessary delays. So lately I've stopped using CNAMEs, and I've
stopped redirecting between URLs with and without the leading www.

Changing the domain's name servers
----------------------------------

As I said, when you register the domain, the registrar configures its
own name servers to act as the domain's name servers, and also tells
the upstream name servers the ip addresses and/or names of the domain's
name servers. While this is normally sufficient, there are cases when
you will want to use other name servers instead of the registrar's name
servers. For example, Digital Ocean offers name servers and a web
interface to configure them, and if Digital Ocean's web interface is
easier, or if it integrates well with droplets making configuration
faster, you might want to use that.  In such a case, you can go to the
registrar's web interface and specify different name servers. The
registrar will tell the upstream name servers which are your new name
servers. It can't setup the new name servers themselves, you have to do
that yourself (e.g. via the Digital Ocean's web interface if you are
using Digital Ocean's name servers).

In this case, you must be aware that while, as we saw in the previous
section, you can configure the TTL for the DNS records of your domain,
**you cannot configure the TTL of the upstream name servers**. The
upstream name servers, when queried about your domain, respond with
something like "the name servers for the requested domain are such and
such, and you can cache this information for 2 days". This TTL,
typically 2 days, is not configurable by you, so you have to live with
it. So changing name servers is a bit risky, because if you do anything
wrong, different users will experience different downtimes that can last
for up to 2 days.

Finally, some information about the NS record, which means "name
server". I haven't told you, but the DNS database (the zone file, as it
is called) for djangodeployment.com also contains these records:

==== ==== ===== ===================
Name Type TTL   Value
==== ==== ===== ===================
@    NS   28800 nsa.bookmyname.com.
@    NS   28800 nsb.bookmyname.com.
@    NS   28800 nsc.bookmyname.com.
==== ==== ===== ===================

(As you can see, there can be many records with the same type and name,
and this is true of A and AAAA records as well—one name may map to many
IP addresses, but we will not delve into that here.)

I have never really understood the reason for the existence of these
records **in the domain's zone file**. The upstream name servers
obviously need to know that, but what's the use of querying a domain's
name server about which are the domain's name servers? Obviously I
already know them.  However, `there is a reason`_, and these records
need to be present both in the domain's name servers and upstream.

.. _there is a reason: http://serverfault.com/questions/588244/what-is-the-role-of-ns-records-at-the-apex-of-a-dns-domain

In any case, these NS records are virtually always configured
automatically by the registrar or by the web interface of the name
server provider, so usually you don't need to know more about it. What
you need to know, however, is that DNS is a complicated system that
easily fills in several books by itself. It will work well if you are
gentle with it. If you want to do something more advanced and you don't
really know what you are doing, ask for help from an expert if you can't
afford the downtime.

.. _editing_the_hosts_file:

Editing the hosts file
----------------------

As I told you earlier, when your browser needs to know the IP address
that corresponds to a name, it asks your operating system's resolver,
and the resolver asks the name server. It is possible to bypass the
asking of the name server and tell the resolver what answers to give.
This is done by modifying the ``hosts`` file, which in Unixes is
``/etc/hosts``, and in Windows is
``C:\Windows\System32\drivers\etc\hosts``. Edit the file and add these
lines at the end::

    1.2.3.4 mysite.com
    1.2.3.4 www.mysite.com

Save the file, restart your browser (because, remember, it may be
caching names), and then visit mysite.com. It will probably fail to
connect (because 1.2.3.4 does not exist), but the thing is that
mysite.com has resolved to 1.2.3.4. The resolver found it in the
``hosts`` file, so it did not ask the DNS server.

I often edit the ``hosts`` file, for experimenting with a temporary
server without needing to change the DNS. Sometimes I want to redirect a
domain to another machine, for development or testing, and I want to do
this only for myself, without affecting the users of the domain. In such
cases the ``hosts`` file comes in handy, and the changes made work
immediately, without needing to wait for DNS caches to expire.

The only thing that you must take care of is to remember to revert the
``hosts`` file to its original contents; if you forget to do so, it
might cause you great headaches later (imagine wondering why the web
site you are deploying is different than what it should be, and
discovering, after hours of searching, that it was because of a
forgotten entry in ``hosts``). What I usually do is leave the editor
open and not close it until after I have reverted the file. When I don't
do that thing, at least I make certain that the domain I'm playing with
is ``example.com`` or anyway something very unlikely to ever be actually
used by me.

Visiting your Django project through the domain
-----------------------------------------------

In the previous chapter you ran Django on a server and it was reachable
through http://$SERVER_IPv4_ADDRESS/. Now you should have setup your
DNS and have $DOMAIN point to $SERVER_IPv4_ADDRESS. In your Django
settings, change ``ALLOWED_HOSTS`` to this::

    ALLOWED_HOSTS = ['$DOMAIN', 'www.$DOMAIN']

Then run the Django development server as in the previous chapter:

.. code-block:: bash

    ./manage.py runserver 0.0.0.0:80

Now you should be able to reach your Django project via http://$DOMAIN/.
So we fixed the first step; we managed to reach Django through a domain
instead of an IP address. Next, we will run Django as an unprivileged
user, and put its files in appropriate directories.

Chapter summary
---------------

* Register your domain at a registrar.
* Use the registrar's web interface to specify A and AAAA records for
  the domain and for www.
* Be careful when you play with TTLs and when changing the domain's name
  servers.
* If you do anything advanced with the DNS and you don't really know
  what you're doing and you can't afford the downtime, ask for expert
  help.
* Set ``ALLOWED_HOSTS = ['$DOMAIN', 'www.$DOMAIN']``.
* Optionally use your local ``hosts`` file for experimentation.
