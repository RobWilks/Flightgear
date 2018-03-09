<?xml version="1.0"?>

<PropertyList>
	<!-- Nasal code -->
	<nasal>
	  

		<load>
			<![CDATA[
			print("Loading tank ", cmdarg().getPath());

      var nodeName=cmdarg().getPath();

      ##checks whether it has been initialized already; if so, just return
      if ( bombable.check_overall_initialized (nodeName) ) return;


			
			#listener function to change livery color if value is change (via dialogue for instance)
			var m1_change_color = func(myTankNodeName) {
          
           
          var damageValue = getprop(""~myTankNodeName~"/bombable/attributes/damage");
          if (damageValue==nil ) damageValue=0;
          
          var use_red = getprop("/ai/m1-abrams/usered");
          
          if (use_red) var base_color = "Models/red"
          else var base_color = "Models/camo";
          
          bombable.set_livery (cmdarg().getPath(), 
             base_color~".png", 
             base_color~"2.png", 
             base_color~"3.png");
          
          
      		if((damageValue >= 0.15) and (damageValue < 1.0))
				  	setprop(""~myTankNodeName~"/bombable/texture-corps-path", base_color~"2.png");
					elsif(damageValue == 1.0)
						setprop(""~myTankNodeName~"/bombable/texture-corps-path" , base_color~"3.png");
					else 
						setprop(""~myTankNodeName~"/bombable/texture-corps-path" , base_color~".png");
			print("listener use_red = ",use_red);
          
      }
			

			
			# Set up M1 Menu with livery change option
			
			var init_m1_dialogs = func () {
        
        #only do this once even if we have multiple m1s loaded in this scenario
        if (getprop ("ai/m1-abrams/init_m1_dialogs")) return;  #it's been done already, so exit
        props.globals.getNode ("ai/m1-abrams/init_m1_dialogs", 1).setBoolValue(1); #so we know it's been done
        
        #we use aircraft. here just as a convenient referable object to add
        # this object to.  This object ("me") has some wacky name like
        # "c:/Program Files/FlightGear/data/AI/M1-Abrams-Bombable/m1.xml" - this is not 
        # only long & complex but will change depending on the system
        # FG is running on.                                  
        aircraft.m1abrams_dlg_config = gui.Dialog.new("ai/m1-abrams/config/dialog","AI/Aircraft/M1-Abrams-Bombable/Dialogs/config.xml");
				
				#aircraft.m1abrams_dlg_config.toggle();
        
        #Doing this via a hot key would work too but the menu option seems better
        #making the keyboard option unnecessary
        setprop ("/input/keyboard/key[15]", "desc", "change M1 Abrams Tank livery color");
        setprop ("/input/keyboard/key[15]", "name", "Ctrl-O");      
        setprop ("/input/keyboard/key[15]/binding", "command", "nasal");
        setprop ("/input/keyboard/key[15]/binding", "module", "__kbd");
        setprop ("/input/keyboard/key[15]/binding", "script", "aircraft.m1abrams_dlg_config.toggle()");
   
        #make the GUI menu
        props.globals.getNode ("/sim/menubar/default/menu[99]/enabled", 1).setBoolValue(1);
        props.globals.getNode ("/sim/menubar/default/menu[99]/label", 1).setValue("M1 Abrams");
        props.globals.getNode ("/sim/menubar/default/menu[99]/item/enabled", 1).setBoolValue(1);
        #Note: the label must be distinct from all other labels in the menubar
        #or you will get duplicate functionality with the other menu item
        #sharing the same label
        props.globals.getNode ("/sim/menubar/default/menu[99]/item/label", 1).setValue("Change M1 livery color");
        props.globals.getNode ("/sim/menubar/default/menu[99]/item/binding/command", 1).setValue("nasal");
        props.globals.getNode ("/sim/menubar/default/menu[99]/item/binding/script", 1).setValue("aircraft.m1abrams_dlg_config.open()");
        
       #reinit makes the property changes to both the GUI & input become active 
       #fgcommand("reinit");
       #As of FG 2.4.0, a straight "reinit" leads to FG crash or the dreaded NAN issue
       #at least with some aircraft.  Reinit/gui (as below) gets around this problem.
       #fgcommand("reinit", props.Node.new({subsystem : "gui"}));
       
       #OK . . . per gui.nas line 63, this appears to be the right way to do this:
       settimer ( func { fgcommand ("gui-redraw"); }, 10);
       
      }
			

############################################
#M1 INITIALIZER
			var m1_init = func() {
				# Datas of this tank are under: cmdarg().getPath()
				var nodeName = cmdarg().getPath();
				var node = props.globals.getNode(nodeName);
				# Add some useful nodes

				#set to use red color (high visibility) by default
				props.globals.getNode ("ai/m1-abrams/usered", 1).setBoolValue(1);
				# function to change color of tank if it is changed in the master dialog box
				setlistener("ai/m1-abrams/usered", func { m1_change_color ( nodeName); });
				

			  var use_red = getprop("/ai/m1-abrams/usered");
          
        if (use_red) var base_color = "Models/red"
        else var base_color = "Models/camo";
        
       
        var color1 = base_color~".png";
        var color2 = base_color~"2.png"; 
        var color3 = base_color~"3.png";
          

        
				
				node.getNode("bombable/texture-corps-path", 1).setValue(base_color~".png");

				node.getNode("surface-positions/cannon-elev-deg", 1).setDoubleValue(20.0);
				node.getNode("surface-positions/turret-pos-deg", 1).setDoubleValue(30.0);
				
        ########################################################################
        ########################################################################
        # INITIALIZE BOMBABLE
        # 
        # Initialize constants and main routines for maintaining altitude
        # relative to ground-level, relocating after file/reset, and 
        # creating bombable/shootable objects.
        # 
        # These routines are found in FG/nasal/bombable.nas
        #  
        ########################################################################               
        # INITIALIZE BOMBABLE Object
        # This object will be slurped in the object's node as a child
        # node named "bombable".                 
        # All distances are specified in meters.
        # All altitudes are relative to current ground level at the object's 
        # location
        # 
         
        thisNodeName = cmdarg().getPath(); 

        var bombableObject = {  
          
          
          objectNodeName : thisNodeName,
          objectNode : props.globals.getNode(thisNodeName),
          updateTime_s : 1/3, #time, in seconds, between the updates that 
          #keep the object at its AGL. Tradeoff is high-speed updates look more
          #realistic but slow down the framerate/cause jerkiness.  Faster-moving
          #objects will need more frequent updates to look realistic.
          #Update Time faster than about 1/3 seems to noticeably 
          #slow the frame rate          

		                        
          #########################################                              
          # ALTITUDE DEFINITIONS
          #         
          # all in meters
          #                     
          altitudes : {	
            wheelsOnGroundAGL_m : 3 , #altitude correction to add to your aircraft or ship that is needed to put wheels on ground (or, for a ship, make it float in the water at the correct level).  For most objects this is 0 but some models need a small correction to place them exactly at ground level
            
            minimumAGL_m : 0, #minimum altitude above ground level this object is allowed to fly
            maximumAGL_m : 0, #maximum altitude AGL this object is allowed to fly	    
            crashedAGL_m : -0.1, #altitude AGL when crashed.  Ships will sink to this level, aircraft or vehicles will sink into the ground as landing gear collapses or tires deflate. Should be negative, even just -0.001.
          },
          #  
          #########################################
          # VELOCITIES DEFINITIONS
          # 
          velocities : {               
            maxSpeedReduce_percent : 5.31, #max % to reduce speed, per step, when damaged
            minSpeed_kt : 0, #minimum speed to reduce to when damaged.  Ground vehicles and ships might stop completely when damaged but aircraft will need a minimum speed so they keep moving until they hit the ground.  Vs for aircraft (http://en.wikipedia.org/wiki/V_speeds)
            
            cruiseSpeed_kt : 25, #cruising speed, typical/optimal cruising speed, V C for aircraft
            
            attackSpeed_kt : 35, #typical/optimal speed when aggressively attacking or evading, in
                                 #level flight for aircraft
            
            maxSpeed_kt : 42,#Maximum possible speed under dive or downhill conditions, V NE for aircraft
    
            damagedAltitudeChangeMaxRate_meterspersecond : 0.02, #max rate to sink or fly downwards when damaged, in meters/second
          },
          #  
          #########################################
          # EVASION DEFINITIONS
          # 
          # The evasion system makes the AI aircraft dodge when they come under
          # fire. 
          evasions : {               
            dodgeDelayMax_sec : 8, #max time to delay/wait between dodges
            dodgeDelayMin_sec : 2, #minimum time to delay/wait between dodges
            dodgeMax_deg : 70, #Max amount to turn when dodging
            dodgeMin_deg : 20, #minimum amount to turn when dodging
            rollRateMax_degpersec : 1, #you can figure this out by rolling the corresponding FG aircraft and timing a 180 or 360 deg roll             
            dodgeROverLPreference_percent : 50, # Preference for right turns vs. left when dodging.  90% means 90% right turns, 50% means 50% right turns.
            dodgeAltMin_m : 0, #Aircraft will begin to move up or down 
            dodgeAltMax_m : 0, #Max & Min are relative to current alt  
          }, 
  
          #  
          #########################################
          # ATTACK DEFINITIONS
          # 
          # The attack system makes the AI aircraft turn and fly towards 
          # other aircraft 
          attacks : {               
            maxDistance_m : 5000, #max distance to turn & attack main aircraft
            minDistance_m : 1, #min distance to turn & attack main aircraft, 
               #ie, fly away this far before turning to attack again.  If you 
               #make this short it will be more like a turning fighter (Zero),
               #longer will become more like an energy fighter that zooms
               #way out, turns around, etc.
            
            continueAttackAngle_deg : 60, #when within minDistance_m, the aircraft will continue to turn towards the main aircraft and attack *if* if the angle is less than this amount from dead ahead.  A wider angle will make it work more like a twisty/turning fighter, narrower angle more like an energy fighter.
            altitudeHigherCutoff_m : 5000, # will attack the main aircraft unless this amount higher than it or more
            altitudeLowerCutoff_m : 5000, # will attack the main aircraft unless this amount lower than it or more 
            rollMin_deg : 3, #when turning on attack, roll to this angle min
            rollMax_deg : 7, #when turning on attack, roll to this angle max
            rollRateMax_degpersec : 1, #you can figure this out by rolling the corresponding FG aircraft and timing a 180 or 360 deg roll
            climbPower : 0, # How powerful the aircraft is when climbing during an attack; 4000 would be typical for, say a Zero--scale accordingly for others; higher is stronger
            divePower : 0, # How powerful the aircraft is when diving during and attack; 6000 typical of a Zero--could be much more than climbPower if the aircraft is a weak climber but a strong diver             
            attackCheckTime_sec : 10, # check for need to attack/correct course this often  
            attackCheckTimeEngaged_sec : 1, # once engaged with enemy, check/update course this frequently                
    
          },
          #  
          #########################################
          # WEAPONS DEFINITIONS
          # 
          # The weapons system makes the AI aircraft fire on the main aircraft 
          # You can define any number of weapons--just enclose each in curly brackets
          # and separate with commas (,).      
          # M1 only has one cannon but since we can't swivel it yet with Bombable
          # let's fake it with front & rear-facing weapons.     
          weapons : {
             front_aim :  #internal name - this can be any name you want; must be a valid nasal variable name
              {               
                name : "M256A1 120 mm gun, M830A1 round", # name presented to users, ie in on-screen messages
                maxDamage_percent : 25, # maximum percentage damage one hit from the aircraft's main weapon/machine guns will do to an opponent
                maxDamageDistance_m : 200, # maximum distance at which the aircrafts main weapon/maching guns will be able to damage an opponent
                weaponAngle_deg  :  { heading: 0, elevation: 45 }, # direction the aircraft's main weapon is aimed.   
                                                                  # 0,0 = straight ahead, 90,0=directly right, 0,90=directly up, 0,180=directly back, etc.
                weaponOffset_m : {x:0, y:2, z:0}, # Offset of the weapon from the main aircraft center
                weaponSize_m : {start: .35, end: .35 }, # Visual size of the weapon's projectile, in meters, at start & end of its path
  
              },    

              rear_aim :  #internal name - this can be any name you want; must be a valid nasal variable name
              {               
                name : "M256A1 120 mm gun, M830A1 round", # name presented to users, ie in on-screen messages
                maxDamage_percent : 25, # maximum percentage damage one hit from the aircraft's main weapon/machine guns will do to an opponent
                maxDamageDistance_m : 200, # maximum distance at which the aircrafts main weapon/maching guns will be able to damage an opponent
                weaponAngle_deg  :  { heading: 180, elevation: 45 }, # direction the aircraft's main weapon is aimed.   
                                                                  # 0,0 = straight ahead, 90,0=directly right, 0,90=directly up, 0,180=directly back, etc.
                weaponOffset_m : {x:0, y:-2, z:0}, # Offset of the weapon from the main aircraft center
                weaponSize_m : {start: .35, end: .35 }, # Visual size of the weapon's projectile, in meters, at start & end of its path
  
              },   
          },  
                             
          #  
          #########################################
          # DIMENSION DEFINITIONS
          # 
          # all in meters          
          #           
          dimensions : {                  
            width_m : 3.66,  #width of your object, ie, for aircraft, wingspan
            length_m : 9.77, #length of your object, ie, for aircraft, distance nose to tail
            height_m : 2.44, #height of your object, ie, for aircraft ground to highest point when sitting on runway
            damageRadius_m : 6, #typically 1/2 the longest dimension of the object. Hits within this distance of the 
                                #center of object have some possibility of damage
            vitalDamageRadius_m : 6, #typically the radius of the fuselage or cockpit or other most 
                                     # vital area at the center of the object.  Always smaller than damageRadius_m 
          },
          #
          #########################################
          # VULNERABILITIES DEFINITIONS        
          #
          vulnerabilities : {                   
            damageVulnerability : 1, #Vulnerability to damage from armament, 1=normal M1 tank; higher to make objects easier to kill and lower to make them more difficult.  This is a multiplier, so 5 means 5X easier to kill than an M1, 1/5 means 5X harder to kill. 
            
            engineDamageVulnerability_percent : 1, #Chance that a small-caliber machine-gun round will damage the engine.       
            
            fireVulnerability_percent : 20, #Vulnerability to catching on fire. 100% means even the slightest impact will set it on fire; 20% means quite difficult to set on fire; 0% means set on fire only when completely damaged; -1% means never set on fire.                          
            
            fireDamageRate_percentpersecond : 0.2, #Amount of damage to add, per second, when on fire.  100%=completely damaged.
            
            fireExtinguishMaxTime_seconds : 100, #Once a fire starts, for this many seconds there is a chance to put out the fire; fires lasting longer than this won't be put out until the object burns out.
            
            fireExtinguishSuccess_percentage : 23, #Chance of the crew putting out the fire within the MaxTime above.
            
            explosiveMass_kg : 58967 , #mass of the object in KG, but give at least a 2-10X bonus to anything carrying flammables or high explosives.
          },
          #
          #########################################
          # LIVERY DEFINITIONS
          #
          # Path to livery files to use at different damage levels.
          # Path is relative to the AI aircraft's directory.
          # The object will start with the first livery listed and 
          # change to succeeding liveries as the damage
          # level increases. The final livery should indicate full damage/
          # object destroyed.        
          # 
          # If you don't want to specify any special liveries simply set 
          # damageLivery : nil and the object's normal livery will be used.  
          #                                                            
          damageLiveries : {
            damageLivery : [  base_color~".png",
                              base_color~"2.png", 
                              base_color~"3.png",
                           ]                        
          },
                            
        };

        #########################################
        # INITIALIZE ROUTINES
        # 
        # OVERALL INITIALIZER: Needed to make all the others work
        bombable.initialize ( bombableObject );
        #
        # LOCATION: Relocate object to maintain its position after file/reset       
        bombable.location_init ( thisNodeName );
        #
        # GROUND: Keep object at altitude relative to ground level
        bombable.ground_init ( thisNodeName );
        #
        # BOMBABLE: Make the object bombable/damageable        
        bombable.bombable_init ( thisNodeName );
        #
        # WEAPONS: Make the object shoot the main aircraft        
        bombable.weapons_init ( thisNodeName );        
        #
        # SMOKE/CONTRAIL: Start a flare, contrail, smoke trail, or exhaust 
        # trail for the object.
        # Smoke types available: flare, jetcontrail, pistonexhaust, smoketrail,
        # damagedengine                        
        bombable.startSmoke("flare", thisNodeName );
        #
        # END INITIALIZE BOMBABLE
        ########################################################################
        ########################################################################                
	      


			
				
			};
      init_m1_dialogs ();
			m1_init();
			]]>
		</load>
		<unload>
			<![CDATA[
			print("Unload tank.");
			
	    ########################################################################
      ########################################################################                
			# BOMBABLE DESTRUCTORS      			
			# 			
      var nodeName= cmdarg().getPath();  
      bombable.de_overall_initialize( nodeName );      
      bombable.initialize_del( nodeName );
      bombable.ground_del( nodeName );
      bombable.location_del (nodeName);      
      bombable.bombable_del( nodeName );
      bombable.weapons_del (nodeName);      
      #
	    ########################################################################
      ########################################################################                
      
      
#  </unload>

			]]>
		</unload>
 </nasal>  
</PropertyList>
