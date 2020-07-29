class ForcedDownMetric
  def current_health
    throw(:force_state, :down)
  end

  def to_s
    self.class.name
  end
end
