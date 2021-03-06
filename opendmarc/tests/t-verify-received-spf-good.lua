-- Copyright (c) 2021, The Trusted Domain Project.  All rights reserved.

-- Test message with a valid (the way DMARC wants it) Received-SPF field
-- 
-- Confirms that a message with a Received-SPF field that indicates a "pass",
-- includes "identity=mailfrom", and includes "envelope-from" with the
-- right value, will be trusted.  Also confirms that quoting inside
-- Received-SPF is handled properly, and the local-part is not used as part
-- of the comparison.

mt.echo("*** Received-SPF test (good)")

-- setup
sock = "unix:" .. mt.getcwd() .. "/t-verify-received-spf-good.sock"
binpath = mt.getcwd() .. "/.."
if os.getenv("srcdir") ~= nil then
	mt.chdir(os.getenv("srcdir"))
end

-- try to start the filter
mt.startfilter(binpath .. "/opendmarc", "-l",
               "-c", "t-verify-received-spf-good.conf", "-p", sock)

-- try to connect to it
conn = mt.connect(sock, 40, 0.05)
if conn == nil then
	error("mt.connect() failed")
end

-- send connection information
-- mt.negotiate() is called implicitly
if mt.conninfo(conn, "localhost2", "127.0.0.2") ~= nil then
	error("mt.conninfo() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.conninfo() unexpected reply")
end

-- send envelope macros and sender data
-- mt.helo() is called implicitly
mt.macro(conn, SMFIC_MAIL, "i", "t-verify-received-spf-good")
if mt.mailfrom(conn, "user@trusteddomain.org") ~= nil then
	error("mt.mailfrom() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.mailfrom() unexpected reply")
end

-- send headers
-- mt.rcptto() is called implicitly
if mt.header(conn, "Received-SPF", "pass identity=mailfrom; envelope-from=\"somebody@trusteddomain.org\"") ~= nil then
	error("mt.header(Received-SPF) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(Received-SPF) unexpected reply")
end
if mt.header(conn, "From", "user@trusteddomain.org") ~= nil then
	error("mt.header(From) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(From) unexpected reply")
end
if mt.header(conn, "To", "user@example.com") ~= nil then
	error("mt.header(To) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(To) unexpected reply")
end
if mt.header(conn, "Date", "Tue, 22 Dec 2009 13:04:12 -0800") ~= nil then
	error("mt.header(Date) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(Date) unexpected reply")
end
if mt.header(conn, "Subject", "DMARC test") ~= nil then
	error("mt.header(Subject) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(Subject) unexpected reply")
end

-- send EOH
if mt.eoh(conn) ~= nil then
	error("mt.eoh() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.eoh() unexpected reply")
end

-- end of message; let the filter react
if mt.eom(conn) ~= nil then
	error("mt.eom() failed")
end
if mt.getreply(conn) ~= SMFIR_ACCEPT then
	error("mt.eom() unexpected reply")
end

-- verify that an Authentication-Results header field got added
if not mt.eom_check(conn, MT_HDRINSERT, "Authentication-Results") and
   not mt.eom_check(conn, MT_HDRADD, "Authentication-Results") then
	error("no Authentication-Results added")
end

-- verify that a DMARC pass result was added
n = 0
found = 0
while true do
	ar = mt.getheader(conn, "Authentication-Results", n)
	if ar == nil then
		break
	end
	if string.find(ar, "dmarc=pass", 1, true) ~= nil then
		found = 1
		break
	end
	n = n + 1
end
if found == 0 then
	error("incorrect DMARC result")
end

mt.disconnect(conn)
