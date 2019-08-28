require 'spec_helper'

describe GraphQLIncludable::New::IncludesBuilder do
  describe 'Basic includes path' do
    context 'A single association' do
      it 'includes :test' do
        builder = subject
        builder.path(:test)
        expect(builder.included_path).to eq([:test])
        expect(builder.active_record_includes).to eq([:test])
      end
    end

    context 'A nested association' do
      it 'includes [:test, :nested]' do
        builder = subject
        builder.path(:test, :nested)
        expect(builder.included_path).to eq([:test, :nested])
        expect(builder.active_record_includes).to eq(test: [:nested])
      end

      it 'includes [:test, :nested]' do
        builder = subject
        builder.path(:test) do
          path(:nested)
        end
        expect(builder.included_path).to eq([:test, :nested])
        expect(builder.active_record_includes).to eq(test: [:nested])
      end

      it 'includes [:nested]' do
        builder = subject
        builder.path do
          path(:nested)
        end
        expect(builder.included_path).to eq([:nested])
        expect(builder.active_record_includes).to eq([:nested])
      end

      it 'includes [:test, :nested, :deeper]' do
        builder = subject
        builder.path(:test) do
          path(:nested) do
            path(:deeper)
          end
        end
        expect(builder.included_path).to eq([:test, :nested, :deeper])
        expect(builder.active_record_includes).to eq(test: { nested: [:deeper] })
      end
    end

    context 'Multiple sibling calls to path' do
      it 'it raises error inside `path`' do
        builder = subject
        expect do
          builder.path(:test) do
            path(:nested) do
              path(:deeper) do
                path(:a)
              end
              path(:sibling) do
                path(:b)
                path(:c)
              end
            end
          end
        end.to raise_error(ArgumentError)
      end

      it 'it does not raise error inside `sibling_path`' do
        builder = subject
        builder.path(:test) do
          sibling_path(:nested) do
            path(:deeper) do
              path(:a)
            end
            path(:sister)
            sibling_path(:brother) do
              path(:b)
              path(:c)
            end
          end
        end

        expect(builder.included_path).to eq([:test])
        expect(builder.active_record_includes).to eq(test: { nested: [:sister, { brother: [:b, :c], deeper: [:a] }] })
      end
    end
  end

  describe 'Extra includes' do
    context 'A single association with a single extra path' do
      it 'includes :test' do
        builder = subject
        builder.path(:test) do
          sibling_path(:sibling)
        end
        expect(builder.included_path).to eq([:test])
        expect(builder.active_record_includes).to eq(test: [:sibling])
      end
    end
  end
end
