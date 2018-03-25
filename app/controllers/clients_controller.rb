# @restful_api 1.0
# Client display and search
class ClientsController < ApplicationController
  def index
    require_relative '../nmap/envizon_cpe'
  end

  # @url /clients/:id
  # @action GET
  #
  # renders client details
  def show
    respond_to do |format|
      format.html { redirect_to root_path }
      format.js { render :show, locals: { client: Client.find(params[:id]) } }
    end
  end

  # @url /clients/global_search
  # @action POST
  #
  # @required [Hash<_unused, Hash>] :search_name Name of the resulting search group
  # @optional [String] :group[:name] Name of the new group
  def global_search
    @clients = Client.all

    if params.key?(:search)
      @search_name = (params[:search_name].empty? ? 'Custom Search' : params[:search_name])

      or_result = nil
      params[:search].each_pair do |_not_used, param|
        next unless %i[table name value not].all? { |key| param[key].present? }

        matched = match_search_element(@clients, param)

        if param.key?(:or) && param[:or].casecmp('true').zero?
          or_result = match_or_search(or_result, matched)
        elsif or_result
          or_result = match_or_search(or_result, matched)
          @clients = match_and_search(@clients, or_result)
          or_result = nil
        else
          @clients = match_and_search(@clients, matched)
        end
      end

      if or_result
        @clients = match_and_search(@clients, or_result)
        or_result = nil
      end

      respond_to do |format|
        format.html { redirect_back fallback_location: root_path }
        format.js { render :search_result }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path }
        format.js { render :select_error }
      end
    end
  end

  def search; end

  def match_search_element(clients, input)
    table = input[:table].downcase
    name = input[:name].downcase
    value = input[:value].downcase

    unless %w[output_port output_client].include?(table)
      table_record = table.classify.constantize
      arel_table = table_record.arel_table
    end

    result = if table == 'client'
               clients.where(arel_table[name].matches("%#{value}%"))
             elsif table == 'port' && name == 'number'
               if value =~ /\A\d+\Z/
                 clients.joins(table.pluralize.to_sym)
                        .where(arel_table[name]
                        .eq(value))
               else
                 match_and_search(clients, clients.joins(:ports))
               end
             elsif table == 'output'
               output(clients, input)
             elsif %w[output_port output_client].include?(table)
               output_helper(clients, input)
             elsif table_record.column_names.include?(name)
               clients.joins(table.pluralize.to_sym)
                      .where(arel_table[name]
                      .matches("%#{value}%"))
             end
    is_not = value.present? ? input[:not].casecmp('true').zero? : !input[:not].casecmp('true').zero?

    result = clients.where.not(id: result.pluck(:id)).group(:id) if is_not && result
    result
  end

  private

  def output(clients, input)
    value = input[:value].downcase if input[:value].present?
    output_param_name = { name: 'name', value: value, not: 'false' }

    output_param_value = { name: 'value', value: value, not: 'false' }

    if value.present?
      output_param_name[:table] = 'output_client'
      output_param_value[:table] = 'output_client'
      result_output_client = match_or_search(match_search_element(clients, output_param_name),
                                             match_search_element(clients, output_param_value))

      output_param_name[:table] = 'output_port'
      output_param_value[:table] = 'output_port'
      result_output_port = match_or_search(match_search_element(clients, output_param_name),
                                           match_search_element(clients, output_param_value))
      match_or_search(result_output_client, result_output_port)
    else
      match_or_search(match_and_search(clients, clients.joins(:outputs)),
                      match_and_search(clients, clients.joins(ports: :outputs)))
    end
  end

  def output_helper(clients, input)
    table_name = input[:table].downcase
    name = input[:name].downcase
    value = input[:value].downcase

    arel_table = Output.arel_table

    if table_name.include?('client')
      clients.joins(:outputs)
             .where(arel_table[name]
             .matches("%#{value}%"))
    else
      clients.joins(ports: :outputs)
             .where(arel_table[name]
             .matches("%#{value}%"))
    end
  end

  def match_and_search(result, input)
    return result unless input
    result.where.not(id: @clients.where.not(id: input.pluck(:id))).group(:id)
  end

  def match_or_search(result, input)
    return result if input.nil?
    result.nil? ? input : @clients.where(id: result.pluck(:id)).or(@clients.where(id: input.pluck(:id))).group(:id)
  end

end
