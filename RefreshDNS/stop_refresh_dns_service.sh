#!/bin/bash
echo "Tearing down refresh-dns ..."
if [ -f /tmp/refresh-dns-activated ]; then
	rm /tmp/refresh-dns-activated
else
	echo "Refresh DNS service is not running"
fi

