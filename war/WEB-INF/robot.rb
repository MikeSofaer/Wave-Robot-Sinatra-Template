require 'lib/waveapi/init'

class Robot < AbstractRobot
  def extra_commands
    ["name"]
  end
  def name(params)
    @name
  end
  def DOCUMENT_CHANGED(properties, context)
    root_wavelet = context.GetRootWavelet()
    root_wavelet.CreateBlip().GetDocument().SetText("I see you changing the doc!")  
  end
  def whine(events, context)
    root_wavelet = context.GetRootWavelet()
    root_wavelet.CreateBlip().GetDocument().SetText("Why don't you like me?")
  end
end