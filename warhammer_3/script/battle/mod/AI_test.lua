-- import the env libarary
local env = require("ai_test/env")


-- register first deploment callback
env.bm:register_phase_change_callback(
    "Deployment",
    env.setup()
)

-- register callbacks to read the order json and write the observations
env.bm:register_phase_change_callback(
    "Deployed",
    function()
        env.bm:slow_game_over_time(1,5,10,1)
        env.bm:repeat_callback(
            function()
                ModLog("____________________")
                ModLog("*******LOOP*********")
                env.readOrders()
                env.exportObservation()
            end,
            1000,
            "Actions"
        )
    end
)


env.bm:register_results_callbacks(
    function ()
        env.playerVictory()
        env.UI.AutoReset(true)
    end,
    function ()
        env.playerDefeat()
        env.UI.AutoReset(false)
    end
)
