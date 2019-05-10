#!/usr/bin/perl
#
# fritzbox2influxdb.pl
#
# Gather Fritz Box statistics and feed them to influxdb/grafana,
# compatible with https://grafana.com/dashboards/713 by Christian Fetzer
#
# QUICK AND DIRTY HACK STYLE -- DO NOT USE IN PRODUCTION
#
# (C) 2019 Hajo Noerenberg
#
# http://www.noerenberg.de/
# https://github.com/hn/fritzbox2influxdb
#
# apt-get install libwww-perl libsoap-lite-perl
# https://metacpan.org/pod/InfluxDB::LineProtocol
# https://packages.debian.org/buster/libinfluxdb-lineprotocol-perl
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3.0 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
#

use strict;
use SOAP::Lite;
use InfluxDB::LineProtocol qw(data2line);
use LWP::UserAgent;

my $fritzboxhost = 'fritz.box:49000';
my $influxhost   = '127.0.0.1:8086';
my $influxdb     = 'grafana';

my $upnp   = 'http://' . $fritzboxhost . '/igdupnp/control';
my $influx = 'http://' . $influxhost . '/write?precision=ns&db=' . $influxdb;

my $soap;
my $soapreq;
my $influxreq;

$soap    = SOAP::Lite->ns('urn:schemas-upnp-org:service:WANIPConnection:1')->proxy( $upnp . '/WANIPConn1' );
$soapreq = $soap->GetStatusInfo();
my $NewConnectionStatus = $soapreq->valueof('//GetStatusInfoResponse/NewConnectionStatus');
my $NewUptime           = $soapreq->valueof('//GetStatusInfoResponse/NewUptime');
$influxreq .= data2line( 'fritzbox_value', ( $NewConnectionStatus eq 'Connected' ? 1 : 0 ), { 'type_instance' => 'constatus' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', $NewUptime, { 'type_instance' => 'uptime' } ) . "\n";

$soap    = SOAP::Lite->ns('urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1')->proxy( $upnp . '/WANCommonIFC1' );
$soapreq = $soap->GetCommonLinkProperties();
my $NewPhysicalLinkStatus         = $soapreq->valueof('//GetCommonLinkPropertiesResponse/NewPhysicalLinkStatus');
my $NewLayer1DownstreamMaxBitRate = $soapreq->valueof('//GetCommonLinkPropertiesResponse/NewLayer1DownstreamMaxBitRate');
my $NewLayer1UpstreamMaxBitRate   = $soapreq->valueof('//GetCommonLinkPropertiesResponse/NewLayer1UpstreamMaxBitRate');
$influxreq .= data2line( 'fritzbox_value', ( $NewPhysicalLinkStatus eq 'Up' ? 1 : 0 ), { 'type_instance' => 'dslstatus' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', $NewLayer1DownstreamMaxBitRate, { 'type_instance' => 'downstreammax' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', $NewLayer1UpstreamMaxBitRate,   { 'type_instance' => 'upstreammax' } ) . "\n";

$soap    = SOAP::Lite->ns('urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1')->proxy( $upnp . '/WANCommonIFC1' );
$soapreq = $soap->GetAddonInfos();
my $NewTotalBytesReceived = $soapreq->valueof('//GetAddonInfosResponse/NewTotalBytesReceived');
my $NewTotalBytesSent     = $soapreq->valueof('//GetAddonInfosResponse/NewTotalBytesSent');
my $NewByteReceiveRate    = $soapreq->valueof('//GetAddonInfosResponse/NewByteReceiveRate');
my $NewByteSendRate       = $soapreq->valueof('//GetAddonInfosResponse/NewByteSendRate');
$influxreq .= data2line( 'fritzbox_value', $NewTotalBytesReceived,  { 'type_instance' => 'totalbytesreceived' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', $NewTotalBytesSent,      { 'type_instance' => 'totalbytessent' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', 8 * $NewByteReceiveRate, { 'type_instance' => 'receiverate' } ) . "\n";
$influxreq .= data2line( 'fritzbox_value', 8 * $NewByteSendRate,    { 'type_instance' => 'sendrate' } ) . "\n";

print $influxreq . "\n";

my $ua = LWP::UserAgent->new();
$ua->agent($0);
my $response = $ua->post( $influx, 'Content_Type' => 'application/x-www-form-urlencoded', 'Content' => $influxreq );

print $response->status_line . "\n" . $response->headers()->as_string;    # HTTP 204 is ok

