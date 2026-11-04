use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;

my ($CONTROL, $ALT) = ("\x{e009}", "\x{e00a}");
my $json = JSON::PP->new->utf8->canonical;

my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => 2828)
  or die "marionette: $!";
my $buf = '';
my $msg_id = 0;

sub fill {
  my $got = sysread($sock, $buf, 65536, length $buf);
  die "marionette: connection closed" unless $got;
}

sub recv_msg {
  fill() until $buf =~ /^(\d+):/;
  my $size = $1;
  substr($buf, 0, length($size) + 1, '');
  fill() while length($buf) < $size;
  return $json->decode(substr($buf, 0, $size, ''));
}

sub call {
  my ($name, $params) = @_;
  my $payload = $json->encode([0, ++$msg_id, $name, $params // {}]);
  print $sock length($payload) . ':' . $payload;
  $sock->flush;
  my (undef, undef, $error, $result) = @{recv_msg()};
  die "$name: " . $json->encode($error) if $error;
  return $result;
}

sub script {
  my ($source, @args) = @_;
  return call('WebDriver:ExecuteScript', {script => $source, args => \@args})->{value};
}

sub compact {
  return script('return window.gZenCompactModeManager.preference') ? JSON::PP::true : JSON::PP::false;
}

sub chord {
  my @keys = @_;
  my @actions = (
    (map { {type => 'keyDown', value => $_} } @keys),
    (map { {type => 'keyUp', value => $_} } reverse @keys),
  );
  call('WebDriver:PerformActions', {actions => [{type => 'key', id => 'kb', actions => \@actions}]});
  call('WebDriver:ReleaseActions');
  sleep 1;
  return compact();
}

my $read_keys = <<'JS';
return Object.fromEntries(arguments[0].map(id => {
  const el = document.getElementById(id);
  return [id, el && Object.fromEntries(
    ["key", "keycode", "modifiers"].filter(a => el.hasAttribute(a)).map(a => [a, el.getAttribute(a)])
  )];
}));
JS

my ($expected_first, @ids) = @ARGV;
$expected_first = $json->encode($json->decode($expected_first));

recv_msg();
call('WebDriver:NewSession');
call('Marionette:SetContext', {value => 'chrome'});

# CustomKeys applies the file asynchronously after the window opens.
my $deadline = time + 90;
my $keys;
while (1) {
  $keys = script($read_keys, \@ids);
  last if $json->encode($keys->{$ids[0]} // {}) eq $expected_first || time > $deadline;
  sleep 1;
}

my @states = (compact(), chord($CONTROL, 's'), chord($CONTROL, $ALT, 'c'));
print $json->encode({keys => $keys, compact => \@states}), "\n";
