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
        command => '/bin/dd if=/dev/zero of=/dev/lvm.fs bs=1024k count=1',
        creates => '/dev/lvm.fs',
        require => Class['::lvm']
      }

      exec { 'create_loop.fs':
        command => '/sbin/losetup /dev/loop6 /dev/lvm.fs',
        creates => '/dev/loop6',
        require => [Exec['create_lvm.fs'],Package['e2fsprogs']]
      }

      exec { 'scan_vg':
        command => '/sbin/vgscan',
        unless  => '/sbin/vgs | grep myvg',
        require => Exec['create_loop.fs']
      }


      physical_volume { '/dev/loop6':
        ensure  => present,
        require => Exec['scan_vg']
      }

      volume_group { 'myvg':
        ensure           => present,
        physical_volumes => '/dev/loop6',
      }

      logical_volume { 'mylv':
        ensure       => present,
        volume_group => 'myvg',
        size         => '4096K',
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

