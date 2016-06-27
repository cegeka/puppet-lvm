require 'spec_helper_acceptance'

describe 'lvm' do

  describe 'running puppet code' do
    it 'should work with no errors' do
      pp = <<-EOS
      class { '::lvm':
        package_ensure  => 'installed',
        manage_pkg      => true
      }

      exec { 'create_lvm.fs':
        command => '/bin/dd if=/dev/zero of=/dev/sdx bs=1024k count=1',
        creates => '/root/lvm.fs',
        require => Class['::lvm']
      }

      exec { 'create_loop.fs':
        command => '/sbin/losetup /dev/loop7 /dev/sdx',
        creates => '/dev/loop7',
        require => Exec['create_lvm.fs']
      }

      physical_volume { '/dev/loop7':
        ensure  => present,
        require => Exec['create_loop.fs']
      }

      volume_group { 'myvg':
        ensure           => present,
        physical_volumes => '/dev/loop7',
      }

      logical_volume { 'mylv':
        ensure       => present,
        volume_group => 'myvg',
        size         => '100K',
      }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe file '/dev/mapper/myvg-mylv' do
      it { is_expected.to be_file }
    end

  end
end

