UserTag dump_session Order name
UserTag dump_session AddAttr
UserTag dump_session Routine <<EOR
sub {
	my ($name, $opt) = @_;
	my $joiner = $opt->{joiner} || ' ';
	return "Cannot dump or find sessions with session type $Vend::Cfg->{SessionType}."
		if $Vend::Cfg->{SessionType} ne 'File';
	if($opt->{find}) {
		require File::Find;
		my $expire = $Vend::Cfg->{SessionExpire};
		if( int($::Variable->{ACTIVE_SESSION_MINUTES}) ) {
			$expire = $::Variable->{ACTIVE_SESSION_MINUTES} * 60;
		}
		my $now = time();
		$expire = $now - $expire;
		my @files;
		my $wanted = sub {
			return unless -f $_;
			return if (stat(_))[9] < $expire;
			return if /\.lock$/;
			push @files, $_;
		};
		File::Find::find($wanted, $Vend::Cfg->{SessionDatabase});
		return join $joiner, @files;
	}
	elsif (! $name) {
		return "dump-session: Nothing to do.";
	}
	else {
		my $fn = Vend::Util::get_filename($name, 2, 1, $Vend::Cfg->{SessionDatabase});
		return '' unless -f $fn;
		return ::uneval(Vend::Util::eval_file($fn));
	}
}
EOR