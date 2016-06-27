require 'spec_helper_acceptance'

describe 'lvm' do

  describe 'running puppet code' do
    it 'should work with no errors' do
      pp = <<-EOS
      class { '::lvm':
        package_ensure => 'installed
      }

      exec { 'create_lvm.fs':
        command => '/bin/dd if=/dev/zero of=/root/lvm.fs bs=1024k count=1',
        creates => '/root/lvm.fs',
        require => Class['::lvm']
      }

      physical_volume { '/root/lvm.fs':
        ensure  => present,
        require => Exec['create_lvm.fs']
      }

      volume_group { 'myvg':
        ensure           => present,
        physical_volumes => '/dev/hdc',
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

