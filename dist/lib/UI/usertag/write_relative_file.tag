UserTag write-relative-file Documentation <<EOD

=head2 write-relative-file

usage: [write-relative-file file=name]content[/write-relative-file]

Writes a file C<name> in the catalog directory. Name must be relative; it will
return undef if the file name is absolute or contains C<..>.

EOD

UserTag write-relative-file Order file
UserTag write-relative-file hasEndTag
UserTag write-relative-file Routine <<EOR
sub {
	my ($file, $data) = @_;
#::logDebug("writing $file");
	$file =~ m:(.*)/:;
	return undef if Vend::Util::file_name_is_absolute($file);
	return undef if $file =~ /\.\./;
	my $dir = $1;
	use File::Path;
	if($dir and ! -d $dir) {
		return undef if -e $dir;
		File::Path::mkpath([$dir]);
	}
	Vend::Util::writefile(">$file", $data);
}
EOR
