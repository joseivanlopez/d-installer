# frozen_string_literal: true

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require "dinstaller/storage/proposal"
require "dinstaller/config"

describe DInstaller::Storage::Proposal do
  subject(:proposal) { described_class.new(logger, config) }

  let(:logger) { Logger.new($stdout, level: :warn) }
  let(:config) { DInstaller::Config.new(config_data) }
  let(:failed) { false }
  let(:config_data) { {} }

  before do
    path = File.join(FIXTURES_PATH, "empty-hd-50GiB.yaml")
    Y2Storage::StorageManager.create_test_instance.probe_from_yaml(path)

    allow_any_instance_of(Y2Storage::BlkDevice).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)
  end

  describe "#calculate" do
    context "when there is no 'volumes' section in the config" do
      let(:config_data) { {} }

      it "calculates the Y2Storage proposal with a default set of VolumeSpecification" do
        original_new = Y2Storage::MinGuidedProposal.method(:new)

        expect(Y2Storage::MinGuidedProposal).to receive(:new) do |**args|
          expect(args[:settings]).to be_a(Y2Storage::ProposalSettings)
          vols = args[:settings].volumes
          expect(vols).to_not be_empty
          expect(vols).to all(be_a(Y2Storage::VolumeSpecification))

          original_new.call(**args)
        end

        proposal.calculate
      end
    end

    context "when there is a 'volumes' section in the config" do
      let(:config_data) do
        { 
          "storage" => {
            "volumes" => [
              {
                "mount_point" => "/", "fs_type" => "btrfs", "min_size" => "10 GiB",
                "snapshots" => true, "snapshots_percentage" => "300"
              },
              {
                "mount_point" => "/two", "fs_type" => "xfs", "min_size" => "5 GiB",
                "proposed_configurable" => true
              }
            ]
          }
        }
      end

      it "calculates the Y2Storage with the correct set of VolumeSpecification" do
        original_new = Y2Storage::MinGuidedProposal.method(:new)

        expect(Y2Storage::MinGuidedProposal).to receive(:new) do |**args|
          expect(args[:settings]).to be_a(Y2Storage::ProposalSettings)
          vols = args[:settings].volumes
          expect(vols).to all(be_a(Y2Storage::VolumeSpecification))
          expect(vols.map(&:mount_point)).to contain_exactly("/", "/two")

          original_new.call(**args)
        end

        proposal.calculate
      end

      it "manual WIP case for testing that overrides works" do
        root = DInstaller::Storage::Volume.new
        root.mount_point = "/"
        root.snapshots = true

        proposal.calculate({"use_lvm" => true}, volumes: [root])
        expect(proposal.volumes.size).to eq 1
        expect(proposal.volumes.first.fixed_size_limits).to eq false
        #byebug
        puts "The usual puts"
      end
    end

    xcontext "when the Y2Storage proposal successes" do
      let(:failed) { false }

      it "saves the proposal" do
        expect(y2storage_manager).to receive(:proposal=).with y2storage_proposal
        proposal.calculate
      end
    end

    xcontext "when the Y2Storage proposal fails" do
      let(:failed) { true }

      it "does not save the proposal" do
        allow(y2storage_manager).to receive(:staging=)
        expect(y2storage_manager).to_not receive(:proposal=)
        proposal.calculate
      end
    end
  end
end
