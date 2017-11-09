require 'spec_helper_acceptance'

describe 'lvm' do

  describe 'running puppet code' do
    it 'should work with no errors' do
      pp = <<-EOS
      class { '::lvm':
        package_ensure  => 'installed',
        manage_pkg      => true
      }

      package { 'e2fsprogs':
        ensure => present
      }

      exec { 'create_lvm.fs':
        command => '/bin/dd if=/dev/zero of=/tmp/lvm.fs bs=10M count=1',
        creates => '/tmp/lvm.fs',
        require => [Class['::lvm'],Package['e2fsprogs']]
      }

      exec { 'create_loop.fs':
        command => '/sbin/losetup /dev/loop6 /tmp/lvm.fs',
        creates => '/dev/loop6',
        require => Exec['create_lvm.fs']
      }

      physical_volume { '/dev/loop6':
        ensure  => present,
        require => Exec['create_loop.fs']
      }

      exec { 'scan_vg':
        command => '/sbin/vgscan',
        unless  => '/sbin/vgs | grep myvg',
        require => Physical_volume['/dev/loop6']
      }

      volume_group { 'myvg':
        ensure           => present,
        physical_volumes => '/dev/loop6',
        require          => Physical_volume['/dev/loop6']
      }

      logical_volume { 'mylv':
        ensure       => present,
        volume_group => 'myvg',
        size         => '4096K',
        require      => Volume_group['myvg']
      }

      exec { 'mknodes':
        command => '/sbin/vgscan --mknodes',
        creates => '/dev/mapper/myvg-mylv',
        require => Logical_volume['mylv']
      }

      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe file '/dev/mapper/myvg-mylv' do
      it { is_expected.to be_block_device }
    end

  end
end
