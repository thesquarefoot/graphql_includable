require 'spec_helper'

describe GraphQLIncludable::New::Includes do
  subject { described_class.new(nil) }
  describe '#active_record_includes' do
    context 'when empty' do
      it 'returns no includes' do
        expect(subject.active_record_includes).to eq({})
      end
    end

    context 'with 1 included key' do
      it 'returns an array with 1 key' do
        subject.add_child(:a)
        expect(subject.active_record_includes).to eq([:a])
      end
    end

    context 'with multiple sibling keys' do
      it 'returns an array with 3 keys' do
        subject.add_child(:a)
        subject.add_child(:b)
        subject.add_child(:c)
        expect(subject.active_record_includes).to eq([:a, :b, :c])
      end
    end

    context 'with nested included keys' do
      it 'returns a compatible Active Record shape' do
        subject.add_child(:a)
        nested_b = subject.add_child(:b)
        nested_b.add_child(:b_2)
        nested_c = subject.add_child(:c)
        nested_c.add_child(:c_1)
        nested_c2 = nested_c.add_child(:c_2)
        nested_c2.add_child(:c_2_1)
        nested_c2.add_child(:c_2_2)

        expect(subject.active_record_includes).to eq([:a, { b: [:b_2], c: [:c_1, { c_2: [:c_2_1, :c_2_2] }] }])
      end
    end
  end
end
