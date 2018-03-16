=head1 NAME

Conch::Route::Orc

=head1 DESCRIPTION

Mojo routes for Conch's orchestration system

=head1 SYNOPSIS

Conch::Route::Orc->load( $r );

=head1 METHODS

=cut

package Conch::Route::Orc;

use Mojo::Base -base, -signatures;


=head2 load

Load up all the routes and attendant subsystems

=cut

use Conch::Orc;
use Conch::Controller::Orc::Workflows;
use Conch::Controller::Orc::WorkflowExecutions;
use Conch::Controller::Orc::Lifecycles;

sub load ( $class, $r ) {
	my $o = $r->under("/o");

	my $l = $o->under("/lifecycle");
	$l->get("/")->to("Orc::Lifecycles#get_all");
	$l->get("/:id")->to("Orc::Lifecycles#get_one");

	my $e = $o->under("/execution");
	$e->get("/active")->to("Orc::WorkflowExecutions#get_active");
	$e->get("/stopped")->to("Orc::WorkflowExecutions#get_stopped");
	$e->get("/completed")->to("Orc::WorkflowsExecutions#get_completed");


	my $d = $o->under("/device/:id");
	$d->get("/")->to("Orc::Device#get_latest_execution");
	$d->get("/execution")->to("Orc::Device#get_executions");
	$d->get("/lifecycle")->to("Orc::Device#get_lifecycles");
	$d->get("/lifecycle/execution")->to("Orc::Device#get_lifecycles_executions");

	my $w = $o->under("/workflow");
	$w->get("/")->to("Orc::Workflows#get_all");
	$w->post("/")->to("Orc::Workflows#create");

	my $wi = $w->under("/:id");
	$wi->get("/")->to("Orc::Workflows#get_one");
	$wi->post("/")->to("Orc::Workflows#update");
	$wi->get("/delete")->to("Orc::Workflows#delete");
	$wi->post("/step")->to("Orc::Workflows#create_step");


	my $si = $o->under("/step/:id");
	$si->get("/")->to("Orc::WorkflowSteps#get_one");
	$si->post("/")->to("Orc::WorkflowSteps#update");
	$si->delete("/")->to("Orc::WorkflowSteps#delete");

	# Endpoints for livesys and other clients
	my $live = $r->under("/live");

}

1;


__DATA__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License, 
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut

