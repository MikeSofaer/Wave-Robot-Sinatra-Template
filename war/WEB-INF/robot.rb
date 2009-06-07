require 'lib/waveapi/init'

class Robot < AbstractRobot
  def extra_commands
    ["name"]
  end
  def name(params)
    @name
  end
  def DOCUMENT_CHANGED(properties, context)
    wavelet = context.GetWavelets()[0]
    blip = context.GetBlipById(wavelet.GetRootBlipId())
    blip.GetDocument().SetText('Only I get to edit the top blip!')
  end
  def clock(event, context)
    wavelet = context.GetWavelets()[0]
    blip = context.GetBlipById(wavelet.GetRootBlipId())
	blip.GetDocument().SetText("It's " + Time.now.to_s)
  end
end