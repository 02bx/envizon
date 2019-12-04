class Report < ApplicationRecord
  has_many :report_parts, as: :reportable

  def all_issues
    issue_array = []
    report_parts.each do |pt|
      pt.get_child_issues.each do |child|
        issue_array << child if child.type == "Issue"
      end
    end
    return issue_array
  end
end
