require 'lib/waveapi/init'

class Robot < AbstractRobot
  def extra_commands
    ["name", "whine"] #Again, whine is here because Wave isn't reloading capabilities
  end
  def name(params)
    @name
  end
  def DOCUMENT_CHANGED(properties, context)
    wavelet = context.GetWavelets()[0]
    blip = context.GetBlipById(wavelet.GetRootBlipId())
    blip.GetDocument().SetText('Only I get to edit the top blip!')
  end
  def whine(event, context)
    clock(event, context) #Wave isn't reading in the new capabilities info.
  end
  def clock(event, context)
    wavelet = context.GetWavelets()[0]
    blip = context.GetBlipById(wavelet.GetRootBlipId())
	blip.GetDocument().SetText("It's " + Time.now.to_s)
  end
end