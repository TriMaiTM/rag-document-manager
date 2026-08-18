module Admin
  class SettingsController < BaseController
    def index
      @gemini_config = Codexys::GeminiConfiguration.new
      @tesseract_available = Documents::OcrText.tesseract_available?
      @active_job_adapter = Rails.application.config.active_job.queue_adapter
      @cache_store = Rails.cache.class.name
      @database_adapter = ActiveRecord::Base.connection.adapter_name
      @max_contexts = SystemSetting.get("max_contexts", "8")
      @maintenance_mode = SystemSetting.get("maintenance_mode", "false")
    end

    def update
      if settings_params[:chat_model].present?
        SystemSetting.set("chat_model", settings_params[:chat_model])
      end

      if settings_params[:max_contexts].present?
        SystemSetting.set("max_contexts", settings_params[:max_contexts])
      end

      if settings_params[:maintenance_mode].present?
        SystemSetting.set("maintenance_mode", settings_params[:maintenance_mode])
      end

      redirect_to admin_settings_path, notice: "Cập nhật cấu hình hệ thống thành công!"
    end

    private

    def settings_params
      params.require(:settings).permit(:chat_model, :max_contexts, :maintenance_mode)
    end
  end
end
