use Mojo::Base -strict;
use Test::More;
use Test::ConchTmpDB;
use Mojo::Pg;

use Conch::Model::WorkspaceRole;

use Data::Printer;

my $pgtmp = mk_tmp_db() or die;
my $pg = Mojo::Pg->new( $pgtmp->uri );

new_ok('Conch::Model::WorkspaceRole');

my $role_model = new_ok( "Conch::Model::WorkspaceRole", [ pg => $pg ] );

my $role;
subtest "Get list of workspace roles" => sub {
	my $roles = $role_model->list();
	isa_ok( $roles, 'ARRAY' );
	cmp_ok( scalar @$roles, '>', 1 ) or die;
	$role = $roles->[0];
	isa_ok( $role, 'Conch::Class::WorkspaceRole' );
};

subtest "Get role by name" => sub {
	my $role_by_name = $role_model->lookup_by_name( $role->name );
	isa_ok( $role_by_name, 'Conch::Class::WorkspaceRole' );
	is_deeply( $role_by_name, $role );
};

done_testing();
