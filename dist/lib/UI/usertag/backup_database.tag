UserTag backup-database Order tables
UserTag backup-database AddAttr
UserTag backup-database Routine <<EOR
sub {
	my ($tables, $opt) = @_;
	my (@tables) = grep /\S/, split /['\s\0]+/, $tables;
	my $backup_dir =	$opt->{dir}
						|| $::Variable->{BACKUP_DIRECTORY}
						|| "$Vend::Cfg->{VendRoot}/backup";
	my $gnum   = $opt->{gnumeric};
	my $agg = "$backup_dir/DBDOWNLOAD.all";

	my $Max_xls_string = 255;

	eval {
		require Compress::Zlib;
	} if $opt ->{compress};

	eval {
		require Spreadsheet::WriteExcel;
		import Spreadsheet::WriteExcel;
	} if $opt ->{xls};

	undef $opt->{xls} if $@;

	my $xls;
	if($opt->{xls}) {
		$xls = Spreadsheet::WriteExcel->new("$backup_dir/DBDOWNLOAD.xls");
		if($opt->{max_xls_string}) {
			$Max_xls_string = int($opt->{max_xls_string}) || 255;
			$xls->{_xls_strmax} = $Max_xls_string;
		}
	}

	my $gz;

	my @errors;

	if($gnum) {
		open (AGG, ">$agg")
			or die "Cannot write aggregate file $agg; $!\n";
	}
	my $done = 0;
	for my $table (@tables) {
		my $unlink;
		my $db = Vend::Data::database_exists_ref($table);
		my $file = "$backup_dir/" . $db->config('file');
		my $status;
		eval {
			$status = export(
						$table,
						{
							table => $table,
							file => $file,
							type => 'TAB',
						},
					);
		};

		if(! $status) {
			push @errors,
				errmsg(
						"Error exporting %s to %s: %s",
						$table,
						$file,
						$@ || 'unspecified',
					);
			next;
		}

		if($opt->{compress}) {
			my $new = "$file.gz";
			my $gz;
			eval {
				$gz = Compress::Zlib::gzopen($new, "wb")
					or die errmsg("error compressing %s to %s: %s", $new, $agg, $!);
				open(ZIN, $file)
					or die errmsg("error opening %s: %s", $file, $!);
				while(<ZIN>) {
					$gz->gzwrite($_)
						or die
							errmsg("gzwrite error on %s: %s", $new, $gz->gzerror());
				}
				$gz->gzclose();
				close ZIN;
			};
			if($@) {
				push @errors, $@;
				next;
			}
			$unlink = 1;
		}
		if($gnum) {
			print AGG "\f" if $done;
			print AGG "$table\n";
			open(RECENT, $file)
				or do {
					push @errors,
						errmsg("Can't read written file %s: %s", $file, $!);
					next;
				};
			while(<RECENT>) {
				/\t/ and s/^/'/ and
					(
						s/\t(0\d+)/\t'$1/g,
						s/\t\+/\t'+/g,
						s/\t( *\d[^\t]*[-A-Za-z ])/\t'$1/g
					);
				print AGG;
			}
			close RECENT;
		}
		if($xls) {
			my $sheet = $xls->addworksheet($table);
			$sheet->{_xls_strmax} = $Max_xls_string
				if defined $opt->{max_xls_string};
			$sheet->activate($table) if $table eq $Vend::Cfg->{ProductFiles}[0];
			open(RECENT, $file)
				or do {
					push @errors,
						errmsg("Can't read written file %s: %s", $file, $!);
					next;
				};
			my $fstring = <RECENT>;
			chomp $fstring;
			my @fields = split /\t/, $fstring;
			my $maxcol = scalar @fields - 1;
			my $j;
			for($j = 0; $j <= $maxcol; $j++) {
				$sheet->write_string(0, $j, $fields[$j]);
			}
			my $i = 1;
			while(<RECENT>) {
				chomp;
				my @extra;
				my @overflow;
				@fields = split /\t/, $_;
				for($j = 0; $j <= $maxcol; $j++) {
					my $l = 0;
					my $ptr;
					if ( length($fields[$j]) > $Max_xls_string) {
						$overflow[$j] = $fields[$j];
						$extra[$j] = [];
						while ( length($overflow[$j]) > $Max_xls_string) {
							for( ' ', "\n", "&nbsp;" ) {
								$ptr = rindex $overflow[$j], $_, $Max_xls_string;
#::logDebug("char='$_' ptr=$ptr length=" . length($overflow[$j]) ) if $l < 10;
								last if $ptr != -1;
							}
#::logDebug("char='$_' ptr=$ptr\nstring=$overflow[$j]") if $l++ < 10;

							$ptr = 254 if $ptr < 0;

							$ptr++;
							my $string = substr $overflow[$j], 0, $ptr;
							$overflow[$j] = substr $overflow[$j], $ptr;
							push @{$extra[$j]}, $string;
						}
						push @{$extra[$j]}, $overflow[$j];
						$fields[$j] = shift @{$extra[$j]};
					}
					$sheet->write_string($i, $j, $fields[$j]);
				}
				if(@extra) {
					my $max = 0;
					for(@extra) {
						next unless $_;
						my $current = scalar @$_;
						$max = $current if $max < $current;
					}
					for (my $k = 0; $k < $max; $k++) {
						$i++;
						for( $j = 0; $j < scalar @extra; $j++) {
							next unless $_;
							$sheet->write_string($i, $j, $extra[$j][$k]);
						}
					}
				}
				$i++;
			}
			close RECENT;
		}

		unlink($file) if $unlink;
		undef $unlink;
		$done++;
	}

	close AGG if $opt->{compress};

	if($opt->{compress} and $gnum and $gnum =~ /^compress/i) {
		my $file = $agg;
		my $new = "$file.gz";
		eval {
			my $gz = Compress::Zlib::gzopen($new, "wb")
				or die errmsg("error compressing %s to %s: %s", $new, $agg, $!);
			open(ZIN, $file)
				or die errmsg("error opening %s: %s", $file, $!);
			while(<ZIN>) {
				$gz->gzwrite($_)
					or die
						errmsg("gzwrite error on %s: %s", $new, $gz->gzerror());
			}
			$gz->gzclose();
			close ZIN;
		};
		if($@) {
			push @errors, $@;
		}
		else {
			unlink($file);
		}
	}
	if(@errors) {
		$::Scratch->{ui_error} = '<UL><LI>';
		$::Scratch->{ui_error} .= join "<LI>", @errors;
		$::Scratch->{ui_error} .= '</UL>';
	}
	return $done;
}
EOR