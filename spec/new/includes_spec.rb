require 'spec_helper'

describe GraphQLIncludable::New::Includes do
  subject { described_class.new(nil) }

  describe '#dig' do
    it 'digs' do
      a = subject.add_child(:a)
      b = subject.add_child(:b)
      a.add_child(:a_2).add_child(:a_3)
      b.add_child(:b_2)

      expect(subject.dig()).to eq(subject.included_children)
      expect(subject.dig([])).to eq(subject.included_children)

      expect(subject.dig(:a, :a_2).included_children.length).to eq (1)
      expect(subject.dig(:a, :a_2).included_children[:a_3]).not_to be_nil

      expect(subject.dig([:a, :a_2]).included_children.length).to eq (1)
      expect(subject.dig([:a, :a_2]).included_children[:a_3]).not_to be_nil
    end
  end

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

  describe '#merge_includes' do
    let(:other) { described_class.new(nil) }

    context 'simple merge' do
      it 'merges other into subject' do
        other.add_child(:test1)
        subject.add_child(:test2).add_child(:test3)
        subject.merge_includes(other)
        expect(subject.included_children.length).to eq(2)
        expect(subject.included_children.key?(:test1)).to eq(true)
        expect(subject.included_children.key?(:test2)).to eq(true)
        test2 = subject.included_children[:test2]
        expect(test2.included_children.length).to eq(1)
        expect(test2.included_children.key?(:test3)).to eq(true)
      end
    end

    context 'complex merge' do
      it 'merges other into subject' do
        other.add_child(:test1)
        subject.add_child(:test1).add_child(:test2)
        subject.merge_includes(other)
        expect(subject.included_children.length).to eq(1)
        expect(subject.included_children.key?(:test1)).to eq(true)
        test1 = subject.included_children[:test1]
        expect(test1.included_children.length).to eq(1)
        expect(test1.included_children.key?(:test2)).to eq(true)

        expect(other.included_children.length).to eq(1)
        expect(other.included_children.key?(:test1)).to eq(true)
        other_test1 = other.included_children[:test1]
        expect(other_test1.included_children.length).to eq(0)
      end

      it 'merges subject into other' do
        other.add_child(:test1)
        subject.add_child(:test1).add_child(:test2)
        other.merge_includes(subject)

        expect(subject.included_children.length).to eq(1)
        expect(subject.included_children.key?(:test1)).to eq(true)
        test1 = subject.included_children[:test1]
        expect(test1.included_children.length).to eq(1)
        expect(test1.included_children.key?(:test2)).to eq(true)

        expect(other.included_children.length).to eq(1)
        expect(other.included_children.key?(:test1)).to eq(true)
        other_test1 = other.included_children[:test1]
        expect(other_test1.included_children.length).to eq(1)
        expect(other_test1.included_children.key?(:test2)).to eq(true)
      end

      context 'appending to merged children references' do
        it 'does not keep in sync still' do
          subject_test2 = subject.add_child(:test1).add_child(:test2)
          other_test2 = other.add_child(:test1).add_child(:test2)
          test3 = other_test2.add_child(:test3)
          subject.merge_includes(other)

          subject_test2.add_child(:subject)
          other_test2.add_child(:other)
          expect(subject.active_record_includes).to eq(test1: { test2: [:test3, :subject] })
          expect(other.active_record_includes).to eq(test1: { test2: [:test3, :other] })

          test3.add_child(:test4)

          expect(subject.active_record_includes).to eq(test1: { test2: [:subject, { test3: [:test4] }] })
          expect(other.active_record_includes).to eq(test1: { test2: [:other, { test3: [:test4] }] })
        end
      end
    end
  end
end
