using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class RespawnMenu : MonoBehaviour
{
    
    // Start is called before the first frame update
    void Start()
    {
        UnlockMouse();
    }

    // Update is called once per frame
    void Update()
    {

    }

    void UnlockMouse()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }

    public void Respawn()
    {
        SceneManager.LoadScene(2);
    }
}
