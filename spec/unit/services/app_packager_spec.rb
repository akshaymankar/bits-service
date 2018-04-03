# frozen_string_literal: true

require 'spec_helper'

module BitsService
  RSpec.describe AppPackager do
    around do |example|
      Dir.mktmpdir('app_packager_spec') do |tmpdir|
        @tmpdir = tmpdir
        example.call
      end
    end

    def fixture_path(name)
      File.expand_path("../../fixtures/app_packager/#{name}", File.dirname(__FILE__))
    end

    let(:logger) { instance_double(Steno::Logger, error: nil) }
    subject(:app_packager) { AppPackager.new(input_zip, logger: logger) }

    describe '#size' do
      let(:input_zip) { fixture_path('good.zip') }
      let(:size_of_good_zip) { 17 }

      it 'returns the sum of each file size' do
        expect(app_packager.size).to eq(size_of_good_zip)
      end
    end

    describe '#unzip' do
      let(:input_zip) { fixture_path('good.zip') }

      it 'unzips the file given' do
        app_packager.unzip(@tmpdir)

        expect(Dir["#{@tmpdir}/**/*"].size).to eq 4
        expect(Dir["#{@tmpdir}/*"].size).to eq 3
        expect(Dir["#{@tmpdir}/subdir/*"].size).to eq 1
      end

      context 'when the zip contains files with weird permissions' do
          context 'when there are unreadable dirs' do
            let(:input_zip) { fixture_path('unreadable_dir.zip') }

            it 'makes all files/dirs readable to cc' do
              app_packager.unzip(@tmpdir)

              expect(File.readable?("#{@tmpdir}/unreadable")).to be true
            end
          end

          context 'when there are unwritable dirs' do
            let(:input_zip) { fixture_path('undeletable_dir.zip') }

            it 'makes all files/dirs writable to cc' do
              app_packager.unzip(@tmpdir)

              expect(File.writable?("#{@tmpdir}/undeletable")).to be true
            end
          end

          context 'when there are untraversable dirs' do
            let(:input_zip) { fixture_path('untraversable_dir.zip') }

            it 'makes all dirs traversable to cc' do
              app_packager.unzip(@tmpdir)

              expect(File.executable?("#{@tmpdir}/untraversable")).to be true
              expect(File.executable?("#{@tmpdir}/untraversable/file.txt")).to be false
            end
          end
        end

      context 'when the zip destination does not exist' do
        it 'raises an exception' do
          expect {
            app_packager.unzip(File.join(@tmpdir, 'blahblah'))
          }.to raise_exception(BitsService::Errors::ApiError, /destination does not exist/i)
        end
      end

      context 'when the zip is empty' do
        let(:input_zip) { fixture_path('empty.zip') }

        it 'raises an exception' do
          expect {
            app_packager.unzip(@tmpdir)
          }.to raise_exception(BitsService::Errors::ApiError, /The app upload is invalid: Invalid zip archive./)
        end
      end

      describe 'relative paths' do
        context 'when the relative path does NOT leave the root directory' do
          let(:input_zip) { fixture_path('good_relative_paths.zip') }

          it 'unzips the archive, ignoring ".."' do
            app_packager.unzip(@tmpdir)

            expect(File.exist?("#{@tmpdir}/bar/cat")).to be true
          end
        end

        context 'when the relative path does leave the root directory' do
          let(:input_zip) { fixture_path('bad_relative_paths.zip') }

          it 'unzips the archive, ignoring ".."' do
            app_packager.unzip(@tmpdir)

            expect(File.exist?("#{@tmpdir}/fakezip.zip")).to be true
          end
        end
      end

      describe 'symlinks' do
        context 'when the zip contains a symlink that does not leave the root dir' do
          let(:input_zip) { fixture_path('good_symlinks.zip') }

          it 'unzips them correctly without errors' do
            app_packager.unzip(@tmpdir)
            expect(File.symlink?("#{@tmpdir}/what")).to be true
          end
        end

        context 'when the zip contains a symlink pointing to a file out of the root dir' do
          let(:input_zip) { fixture_path('bad_symlinks.zip') }

          it 'raises an exception' do
            expect { app_packager.unzip(@tmpdir) }.to raise_exception(BitsService::Errors::ApiError, /The app upload is invalid: Invalid zip archive./i)
          end
        end
      end

      context 'when there is an error unzipping' do
        it 'raises an exception' do
          allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
          expect {
            app_packager.unzip(@tmpdir)
          }.to raise_error(BitsService::Errors::ApiError, /The app upload is invalid: Invalid zip archive./)
        end
      end

      context 'when there is an error unzipping' do
        before do
          allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        end

        it 'raises an exception' do
          expect {
            app_packager.unzip(@tmpdir)
          }.to raise_error(BitsService::Errors::ApiError, /Invalid zip archive/)
        end
      end

      context 'when there is an error adjusting permissions' do
        before do
          allow(Open3).to receive(:capture3).with(/unzip/).and_return(['output', 'error', double(success?: true)])
          allow(FileUtils).to receive(:chmod_R).and_raise(StandardError.new('bad things happened'))
        end

        it 'raises an exception' do
          expect(logger).to receive(:error).with "Fixing zip file permissions error\n bad things happened"

          expect {
            app_packager.unzip(@tmpdir)
          }.to raise_error(BitsService::Errors::ApiError, /Invalid zip archive/)
        end
      end
    end

    describe '#append_dir_contents' do
      let(:input_zip) { File.join(@tmpdir, 'good.zip') }
      let(:additional_files_path) { fixture_path('fake_package') }

      before { FileUtils.cp(fixture_path('good.zip'), input_zip) }

      it 'adds the files to the zip' do
        app_packager.append_dir_contents(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).not_to include './'
        expect(output).not_to include 'fake_package'

        expect(output).to match /^l.+coming_from_inside$/
        expect(output).to include 'here.txt'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/there.txt'

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greetings'

        expect(output).to include '7 files'
      end

      context 'when there are no additional files' do
        let(:additional_files_path) { File.join(@tmpdir, 'empty') }

        it 'results in the existing zip' do
          Dir.mkdir(additional_files_path)

          output = `zipinfo #{input_zip}`

          expect(output).to include 'bye'
          expect(output).to include 'hi'
          expect(output).to include 'subdir/'
          expect(output).to include 'subdir/greeting'

          expect(output).to include '4 files'

          app_packager.append_dir_contents(additional_files_path)

          output = `zipinfo #{input_zip}`

          expect(output).to include 'bye'
          expect(output).to include 'hi'
          expect(output).to include 'subdir/'
          expect(output).to include 'subdir/greeting'

          expect(output).to include '4 files'
        end
      end

      context 'when there is an error zipping' do
        it 'raises an exception' do
          allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
          expect {
            app_packager.append_dir_contents(additional_files_path)
          }.to raise_error(BitsService::Errors::ApiError, /The app package is invalid: Error appending additional resources to package/)
        end
      end
    end

    describe '#fix_subdir_permissions' do
      context 'when the zip has directories without the directory attribute or execute permission (it was created on windows)' do
        let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }

        before { FileUtils.cp(fixture_path(File.join('app_packager_zips', 'bad_directory_permissions.zip')), input_zip) }

        it 'deletes all directories from the archive' do
          app_packager.fix_subdir_permissions

          has_dirs = Zip::File.open(input_zip) do |in_zip|
            in_zip.any?(&:directory?)
          end

          expect(has_dirs).to be_falsey
        end
      end

      context 'when the zip has directories with special characters' do
        let(:input_zip) { File.join(@tmpdir, 'special_character_names.zip') }

        before { FileUtils.cp(fixture_path(File.join('app_packager_zips', 'special_character_names.zip')), input_zip) }

        it 'successfully removes and re-adds them' do
          app_packager.fix_subdir_permissions
          expect(`zipinfo #{input_zip}`).to match %r{special_character_names/&&hello::\?\?/}
        end
      end

      context 'when there are many directories' do
        let(:input_zip) { File.join(@tmpdir, 'many_dirs.zip') }

        before { FileUtils.cp(fixture_path(File.join('app_packager_zips', 'many_dirs.zip')), input_zip) }

        it 'batches the directory deletes so it does not exceed the max command length' do
          allow(Open3).to receive(:capture3).and_call_original
          batch_size = 10
          stub_const('BitsService::AppPackager::DIRECTORY_DELETE_BATCH_SIZE', batch_size)

          app_packager.fix_subdir_permissions

          output = `zipinfo #{input_zip}`

          (0..20).each do |i|
            expect(output).to include("folder_#{i}/")
            expect(output).to include("folder_#{i}/empty_file")
          end

          number_of_batches = (21.0 / batch_size).ceil
          expect(number_of_batches).to eq(3)
          expect(Open3).to have_received(:capture3).exactly(number_of_batches).times
        end
      end

      context 'when there is an error deleting directories' do
        let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }
        before { FileUtils.cp(fixture_path(File.join('app_packager_zips', 'bad_directory_permissions.zip')), input_zip) }

        it 'raises an exception' do
          allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
          expect {
            app_packager.fix_subdir_permissions
          }.to raise_error(BitsService::Errors::ApiError, /The app package is invalid: Error removing zip directories./)
        end
      end

      context 'when there is a zip error' do
        let(:input_zip) { 'garbage' }

        it 'raises an exception' do
          allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
          expect {
            app_packager.fix_subdir_permissions
          }.to raise_error(BitsService::Errors::ApiError, /The app upload is invalid: Invalid zip archive./)
        end
      end
    end
  end
end
